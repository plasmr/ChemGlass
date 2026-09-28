import Foundation

/// Loads and prepares the bundled JSON data off the main thread.
nonisolated enum DataLoader {

    nonisolated enum LoadError: LocalizedError {
        case missingResource(String)

        var errorDescription: String? {
            switch self {
            case .missingResource(let name):
                return "The bundled file \(name) could not be found."
            }
        }
    }

    @concurrent
    static func loadElements() async throws -> [Element] {
        let data = try bundledData(named: "elements_data")
        return try JSONDecoder().decode([Element].self, from: data)
    }

    /// Decodes the Gold Book, cleans every entry and returns the terms sorted by title.
    @concurrent
    static func loadTerms() async throws -> [Term] {
        let data = try bundledData(named: "goldbook_offline")
        let file = try JSONDecoder().decode(GoldBookFile.self, from: data)

        var terms: [Term] = []
        terms.reserveCapacity(file.terms.list.count)
        for (code, entry) in file.terms.list {
            let title = capitalizingFirstLetter(TextCleaner.clean(entry.title))
            guard !title.isEmpty else { continue }
            terms.append(
                Term(id: code, title: title, status: entry.status, definition: TextCleaner.clean(entry.definition))
            )
        }

        terms.sort { lhs, rhs in
            if lhs.titleKey != rhs.titleKey { return lhs.titleKey < rhs.titleKey }
            return lhs.id < rhs.id
        }
        return terms
    }

    private static func bundledData(named name: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw LoadError.missingResource("\(name).json")
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    /// Unlike `String.capitalized`, this leaves "pH", "DNA" or "mRNA" alone after the first letter.
    private static func capitalizingFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }
}
