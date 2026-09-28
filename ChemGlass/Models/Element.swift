import Foundation

/// One entry of `elements_data.json`.
nonisolated struct Element: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let symbol: String
    let name: String
    let mass: Double
    let category: String
    let row: Int
    let column: Int
    let atomicRadius: Double?
    let electronegativity: Double?
    let electronConfigShorthand: String
    let block: String
    let commonIons: String
    let details: String
}

extension Element {
    /// Common oxidation states with proper signs, e.g. `["−1", "+1"]`.
    nonisolated var oxidationStates: [String] {
        commonIons
            .split(separator: ",")
            .compactMap { part -> String? in
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return nil }
                guard let value = Int(trimmed) else { return trimmed }
                if value > 0 { return "+\(value)" }
                if value < 0 { return "\u{2212}\(-value)" }
                return "0"
            }
    }

    /// Electrons per shell (K, L, M, …) derived from the electron configuration.
    nonisolated var electronShells: [Int]? {
        ElectronConfiguration.shells(from: electronConfigShorthand, atomicNumber: id)
    }

    nonisolated var blockLabel: String { block.lowercased() + "-block" }
}
