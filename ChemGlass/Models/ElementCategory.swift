import SwiftUI

/// A normalised element family used for colours, legends and quizzes.
enum ElementCategory: String, CaseIterable, Identifiable {
    case alkaliMetal, alkalineEarth, transition, postTransition, metalloid
    case nonmetal, halogen, nobleGas, lanthanide, actinide, unknown

    var id: String { rawValue }

    /// Maps the free-text category in `elements_data.json` ("Poor metals", "Noble gases", …).
    init(dataLabel: String) {
        let label = dataLabel.lowercased()
        if label.contains("noble") { self = .nobleGas }
        else if label.contains("halogen") { self = .halogen }
        else if label.contains("alkaline") { self = .alkalineEarth }
        else if label.contains("alkali") { self = .alkaliMetal }
        else if label.contains("poor") || label.contains("post") { self = .postTransition }
        else if label.contains("transition") { self = .transition }
        else if label.contains("metalloid") { self = .metalloid }
        else if label.contains("lanthan") { self = .lanthanide }
        else if label.contains("actin") { self = .actinide }
        else if label.contains("nonmetal") { self = .nonmetal }
        else { self = .unknown }
    }

    var title: String {
        switch self {
        case .alkaliMetal: return "Alkali metals"
        case .alkalineEarth: return "Alkaline earth metals"
        case .transition: return "Transition metals"
        case .postTransition: return "Post-transition metals"
        case .metalloid: return "Metalloids"
        case .nonmetal: return "Nonmetals"
        case .halogen: return "Halogens"
        case .nobleGas: return "Noble gases"
        case .lanthanide: return "Lanthanides"
        case .actinide: return "Actinides"
        case .unknown: return "Unclassified"
        }
    }

    var color: Color {
        switch self {
        case .alkaliMetal: return .orange
        case .alkalineEarth: return .yellow
        case .transition: return .blue
        case .postTransition: return .indigo
        case .metalloid: return .teal
        case .nonmetal: return .green
        case .halogen: return .cyan
        case .nobleGas: return .purple
        case .lanthanide: return .pink
        case .actinide: return .red
        case .unknown: return .gray
        }
    }
}

extension Element {
    var kind: ElementCategory { ElementCategory(dataLabel: category) }
}
