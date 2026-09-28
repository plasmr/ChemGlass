import SwiftUI

/// Root of the app: a glass sidebar, a section router and the ⌘K palette overlay.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.appearance) private var appearance: AppearanceMode = .system

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 260)
        } detail: {
            DetailRouter()
        }
        .containerBackground(for: .window) { Backdrop() }
        .preferredColorScheme(appearance.colorScheme)
        .overlay {
            if model.isPaletteVisible {
                CommandPalette()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.2), value: model.isPaletteVisible)
        .task { await model.load() }
        .frame(minWidth: 1040, minHeight: 700)
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let selection = Binding<AppSection?>(
            get: { model.section },
            set: { newValue in
                if let newValue { model.section = newValue }
            }
        )

        List(AppSection.allCases, selection: selection) { section in
            Label(section.title, systemImage: section.symbolName)
                .tag(section)
        }
        .safeAreaInset(edge: .bottom) {
            if model.loadState == .loaded {
                Text("\(model.elements.count) elements · \(model.terms.count) terms")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
        }
    }
}

struct DetailRouter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.loadState {
            case .idle, .loading:
                LoadingView()
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn’t load the data", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await model.retry() } }
                        .buttonStyle(.glassProminent)
                }
            case .loaded:
                sectionContent
            }
        }
        .navigationTitle(model.section.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Quick Search", systemImage: "magnifyingglass") {
                    model.isPaletteVisible = true
                }
                .help("Quick Search (⌘K)")
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch model.section {
        case .dictionary: DictionaryView()
        case .elements: PeriodicTableView()
        case .trends: TrendsView()
        case .calculator: CalculatorView()
        case .quiz: QuizView()
        case .library: LibraryView()
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Preparing the dictionary…")
                .foregroundStyle(.secondary)
        }
        .padding(36)
        .glassPanel()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
