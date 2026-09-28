import SwiftUI

enum PaletteItem: Identifiable {
    case section(AppSection)
    case element(Element)
    case term(Term)

    var id: String {
        switch self {
        case .section(let section): return "section-\(section.rawValue)"
        case .element(let element): return "element-\(element.id)"
        case .term(let term): return "term-\(term.id)"
        }
    }
}

/// ⌘K quick search across sections, elements and dictionary terms.
struct CommandPalette: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var highlighted = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        let items = search()

        ZStack(alignment: .top) {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search elements, terms and sections", text: $query)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .focused($isFocused)
                        .onSubmit { activate(items) }
                        .onKeyPress(.downArrow) {
                            highlighted = min(highlighted + 1, max(items.count - 1, 0))
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            highlighted = max(highlighted - 1, 0)
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            close()
                            return .handled
                        }
                }
                .padding(16)

                Divider()

                if items.isEmpty {
                    Text("No matches")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(28)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    row(item, isHighlighted: index == highlighted)
                                        .id(item.id)
                                        .onTapGesture { open(item) }
                                }
                            }
                            .padding(8)
                        }
                        .frame(maxHeight: 380)
                        .onChange(of: highlighted) {
                            if items.indices.contains(highlighted) {
                                proxy.scrollTo(items[highlighted].id)
                            }
                        }
                    }
                }
            }
            .frame(width: 640)
            .glassPanel(cornerRadius: 26)
            .padding(.top, 96)
        }
        .onAppear { isFocused = true }
        .onChange(of: query) { highlighted = 0 }
    }

    // MARK: Rows

    private func row(_ item: PaletteItem, isHighlighted: Bool) -> some View {
        HStack(spacing: 12) {
            icon(for: item)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: item)).font(.body.weight(.medium)).lineLimit(1)
                Text(subtitle(for: item)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if isHighlighted {
                Image(systemName: "return").foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            isHighlighted ? Color.accentColor.opacity(0.22) : Color.clear,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func icon(for item: PaletteItem) -> some View {
        switch item {
        case .section(let section):
            Image(systemName: section.symbolName)
                .font(.title3)
                .foregroundStyle(.secondary)
        case .element(let element):
            Text(element.symbol)
                .font(.system(.headline, design: .rounded))
                .frame(width: 34, height: 34)
                .background(element.kind.color.opacity(0.3), in: RoundedRectangle(cornerRadius: 9))
        case .term:
            Image(systemName: "text.book.closed")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func title(for item: PaletteItem) -> String {
        switch item {
        case .section(let section): return section.title
        case .element(let element): return element.name
        case .term(let term): return term.title
        }
    }

    private func subtitle(for item: PaletteItem) -> String {
        switch item {
        case .section: return "Go to section"
        case .element(let element): return "Element \(element.id) · \(element.kind.title)"
        case .term(let term): return term.definition
        }
    }

    // MARK: Behaviour

    private func search() -> [PaletteItem] {
        let needle = TextCleaner.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return AppSection.allCases.map { PaletteItem.section($0) } }

        var items: [PaletteItem] = []
        for section in AppSection.allCases where TextCleaner.fold(section.title).contains(needle) {
            items.append(.section(section))
        }

        var elementMatches: [Element] = []
        for element in model.elements {
            if let number = Int(needle), number == element.id {
                elementMatches.insert(element, at: 0)
            } else if TextCleaner.fold(element.name).contains(needle) || TextCleaner.fold(element.symbol) == needle {
                elementMatches.append(element)
            }
        }
        items += elementMatches.prefix(6).map { PaletteItem.element($0) }

        var prefixMatches: [Term] = []
        var containsMatches: [Term] = []
        for term in model.terms {
            if term.titleKey.hasPrefix(needle) {
                prefixMatches.append(term)
            } else if term.titleKey.contains(needle) {
                containsMatches.append(term)
            }
            if prefixMatches.count >= 10 && containsMatches.count >= 10 { break }
        }
        items += (prefixMatches + containsMatches).prefix(10).map { PaletteItem.term($0) }
        return items
    }

    private func activate(_ items: [PaletteItem]) {
        guard items.indices.contains(highlighted) else { return }
        open(items[highlighted])
    }

    private func open(_ item: PaletteItem) {
        switch item {
        case .section(let section):
            model.section = section
            close()
        case .element(let element):
            model.open(element: element.id)
        case .term(let term):
            model.open(term: term.id)
        }
    }

    private func close() {
        model.isPaletteVisible = false
    }
}
