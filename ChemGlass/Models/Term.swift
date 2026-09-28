import Foundation

/// A cleaned IUPAC Gold Book entry, ready for display and fast searching.
nonisolated struct Term: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let status: String
    let definition: String
    /// Section letter used by the dictionary list ("#" for non-letters).
    let initial: String
    /// Case- and diacritic-folded copies used for searching.
    let titleKey: String
    let definitionKey: String

    init(id: String, title: String, status: String, definition: String) {
        self.id = id
        self.title = title
        self.status = status
        self.definition = definition
        let key = TextCleaner.fold(title)
        self.titleKey = key
        self.definitionKey = TextCleaner.fold(definition)
        if let first = key.first, first.isLetter {
            self.initial = String(first).uppercased()
        } else {
            self.initial = "#"
        }
    }

    var webURL: URL? { URL(string: "https://goldbook.iupac.org/terms/view/\(id)") }

    static func == (lhs: Term, rhs: Term) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

nonisolated struct TermSection: Identifiable, Sendable {
    let id: String
    let terms: [Term]
}

/// Raw shape of `goldbook_offline.json`.
nonisolated struct GoldBookFile: Decodable {
    nonisolated struct Terms: Decodable {
        let list: [String: Entry]
    }

    nonisolated struct Entry: Decodable {
        let title: String
        let status: String
        let definition: String

        private enum CodingKeys: String, CodingKey { case title, status, definition }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
            status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
            definition = try container.decodeIfPresent(String.self, forKey: .definition) ?? ""
        }
    }

    let terms: Terms
}
