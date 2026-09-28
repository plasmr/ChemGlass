import SwiftUI

@main
struct ChemGlassApp: App {
    @State private var model = AppModel()
    @State private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(library)
        }
        .defaultSize(width: 1280, height: 820)
        .commands { NavigationCommands(model: model) }

        Settings {
            SettingsView()
        }
    }
}

/// "Go" menu: ⌘1–⌘6 jump between sections, ⌘K opens quick search.
struct NavigationCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu("Go") {
            ForEach(AppSection.allCases) { section in
                Button(section.title) { model.section = section }
                    .keyboardShortcut(section.shortcut, modifiers: .command)
            }
            Divider()
            Button("Quick Search…") { model.isPaletteVisible = true }
                .keyboardShortcut("k", modifiers: .command)
        }
    }
}
