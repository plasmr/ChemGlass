import SwiftUI

struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(LibraryStore.self) private var library

    var body: some View {
        let favoriteElements = library.favoriteElementIDs.sorted().compactMap { model.elementsByID[$0] }
        let favoriteTerms = library.favoriteTermIDs
            .compactMap { model.termsByID[$0] }
            .sorted { $0.titleKey < $1.titleKey }
        let notedTerms = library.notes.keys
            .compactMap { model.termsByID[$0] }
            .sorted { $0.titleKey < $1.titleKey }
        let recentTerms = library.recentTermIDs.compactMap { model.termsByID[$0] }
        let recentElements = library.recentElementIDs.compactMap { model.elementsByID[$0] }

        let isEmpty = favoriteElements.isEmpty && favoriteTerms.isEmpty && notedTerms.isEmpty
            && recentTerms.isEmpty && recentElements.isEmpty

        if isEmpty {
            ContentUnavailableView(
                "Your library is empty",
                systemImage: "star",
                description: Text("Favorite elements and terms, jot down notes, and everything you open shows up here.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !favoriteElements.isEmpty {
                        LibraryCard(title: "Favorite elements", systemImage: "atom") {
                            elementGrid(favoriteElements)
                        }
                    }
                    if !favoriteTerms.isEmpty {
                        LibraryCard(title: "Favorite terms", systemImage: "star.fill") {
                            termList(favoriteTerms)
                        }
                    }
                    if !notedTerms.isEmpty {
                        LibraryCard(title: "Notes", systemImage: "square.and.pencil") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(notedTerms) { term in
                                    Button { model.open(term: term.id) } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(term.title).font(.headline)
                                            Text(library.note(forTerm: term.id))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if !recentElements.isEmpty || !recentTerms.isEmpty {
                        LibraryCard(title: "Recently viewed", systemImage: "clock") {
                            VStack(alignment: .leading, spacing: 12) {
                                if !recentElements.isEmpty { elementGrid(Array(recentElements.prefix(12))) }
                                if !recentTerms.isEmpty { termList(Array(recentTerms.prefix(8))) }
                                Button("Clear history", role: .destructive) { library.clearRecents() }
                                    .buttonStyle(.glass)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func elementGrid(_ elements: [Element]) -> some View {
        GlassEffectContainer(spacing: 8) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(elements) { element in
                    Button { model.open(element: element.id) } label: {
                        HStack(spacing: 8) {
                            Text(element.symbol).font(.headline)
                            Text(element.name).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .tint(element.kind.color.opacity(0.6))
                }
            }
        }
    }

    private func termList(_ terms: [Term]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(terms) { term in
                Button { model.open(term: term.id) } label: {
                    HStack {
                        Text(term.title).font(.body.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct LibraryCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage).font(.headline)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 24)
    }
}
