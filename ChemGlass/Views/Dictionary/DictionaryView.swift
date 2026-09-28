import SwiftUI
import AppKit

struct DictionaryView: View {
    @Environment(AppModel.self) private var model
    @Environment(LibraryStore.self) private var library

    var body: some View {
        @Bindable var dictionary = model.dictionary

        let criteria = DictionaryModel.Criteria(
            query: dictionary.query,
            searchDefinitions: dictionary.searchDefinitions,
            status: dictionary.statusFilter,
            ascending: dictionary.sortAscending,
            favoritesOnly: dictionary.favoritesOnly,
            favoriteIDs: dictionary.favoritesOnly ? library.favoriteTermIDs : []
        )

        HStack(alignment: .top, spacing: 16) {
            TermListPane()
                .frame(width: 380)
            TermDetailPane()
        }
        .padding(16)
        .searchable(text: $dictionary.query, placement: .toolbar, prompt: "Search \(model.terms.count) IUPAC terms")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Sort", selection: $dictionary.sortAscending) {
                        Text("A → Z").tag(true)
                        Text("Z → A").tag(false)
                    }
                    .pickerStyle(.inline)

                    Picker("Status", selection: $dictionary.statusFilter) {
                        ForEach(dictionary.availableStatuses, id: \.self) { status in
                            Text(status).tag(status)
                        }
                    }
                    .pickerStyle(.inline)

                    Divider()
                    Toggle("Search inside definitions", isOn: $dictionary.searchDefinitions)
                    Toggle("Favorites only", isOn: $dictionary.favoritesOnly)
                } label: {
                    Label("Filters", systemImage: "line.3.horizontal.decrease")
                }
            }
        }
        .task(id: criteria) {
            await dictionary.refresh(terms: model.terms, criteria: criteria)
        }
    }
}

// MARK: - List

struct TermListPane: View {
    @Environment(AppModel.self) private var model
    @Environment(LibraryStore.self) private var library

    private var dictionary: DictionaryModel { model.dictionary }

    var body: some View {
        @Bindable var bindableModel = model
        let favorites = library.favoriteTermIDs

        VStack(spacing: 0) {
            HStack {
                Text(dictionary.resultCount == 1 ? "1 term" : "\(dictionary.resultCount) terms")
                    .font(.headline)
                Spacer()
                if dictionary.isFiltering {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollViewReader { proxy in
                List(selection: $bindableModel.selectedTermID) {
                    ForEach(dictionary.sections) { section in
                        Section(section.id) {
                            ForEach(section.terms) { term in
                                TermRow(term: term, isFavorite: favorites.contains(term.id))
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .overlay { emptyState }
                .onChange(of: model.selectedTermID) { scroll(proxy) }
                .onChange(of: dictionary.resultCount) { scroll(proxy) }
                .onAppear { scroll(proxy) }
            }
        }
        .glassPanel()
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard let id = model.selectedTermID else { return }
        withAnimation(.smooth) { proxy.scrollTo(id, anchor: .center) }
    }

    @ViewBuilder
    private var emptyState: some View {
        if dictionary.sections.isEmpty && !dictionary.isFiltering {
            if dictionary.query.isEmpty {
                ContentUnavailableView("No terms", systemImage: "tray", description: Text("Nothing matches the current filters."))
            } else {
                ContentUnavailableView.search(text: dictionary.query)
            }
        }
    }
}

struct TermRow: View {
    let term: Term
    let isFavorite: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(term.title)
                    .font(.headline)
                    .lineLimit(2)
                if isFavorite {
                    Image(systemName: "star.fill")
                        .imageScale(.small)
                        .foregroundStyle(.yellow)
                }
            }
            Text(term.definition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Detail

struct TermDetailPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if let id = model.selectedTermID, let term = model.termsByID[id] {
                TermDetailView(term: term)
                    .id(term.id)
            } else {
                ContentUnavailableView(
                    "Select a term",
                    systemImage: "text.book.closed",
                    description: Text("Pick a term from the list to read its IUPAC definition.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassPanel()
    }
}

struct TermDetailView: View {
    let term: Term

    @Environment(LibraryStore.self) private var library
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsKey.definitionFontSize) private var fontSize = 20.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                actions
                Text(term.definition)
                    .font(.system(size: fontSize))
                    .lineSpacing(fontSize * 0.35)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                notes
            }
            .padding(32)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { library.recordView(ofTerm: term.id) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TintChip(title: term.status.capitalized, systemImage: "checkmark.seal", tint: statusTint)
                TintChip(title: term.id)
            }
            Text(term.title)
                .font(.system(size: max(30, fontSize * 1.7), weight: .bold, design: .serif))
                .textSelection(.enabled)
        }
    }

    private var statusTint: Color {
        let status = term.status.lowercased()
        if status.contains("obsolete") || status.contains("deprecated") { return .orange }
        if status.contains("current") { return .green }
        return .secondary
    }

    private var actions: some View {
        let isFavorite = library.favoriteTermIDs.contains(term.id)
        let shareText = "\(term.title)\n\n\(term.definition)"

        return GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    library.toggleFavorite(term: term.id)
                } label: {
                    Label(isFavorite ? "Favorited" : "Favorite", systemImage: isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(.glass)
                .tint(isFavorite ? .yellow : nil)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(shareText, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.glass)

                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glass)

                if let url = term.webURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label("IUPAC.org", systemImage: "safari")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var notes: some View {
        let binding = Binding<String>(
            get: { library.note(forTerm: term.id) },
            set: { library.setNote($0, forTerm: term.id) }
        )

        return VStack(alignment: .leading, spacing: 8) {
            Label("My notes", systemImage: "square.and.pencil")
                .font(.headline)
            TextEditor(text: binding)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 120)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
