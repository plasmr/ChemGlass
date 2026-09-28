import SwiftUI
import Observation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case dictionary, elements, trends, calculator, quiz, library

    var id: AppSection { self }

    var title: String {
        switch self {
        case .dictionary: return "Dictionary"
        case .elements: return "Periodic Table"
        case .trends: return "Trends"
        case .calculator: return "Molar Mass"
        case .quiz: return "Quiz"
        case .library: return "Library"
        }
    }

    var symbolName: String {
        switch self {
        case .dictionary: return "text.book.closed.fill"
        case .elements: return "atom"
        case .trends: return "chart.xyaxis.line"
        case .calculator: return "scalemass.fill"
        case .quiz: return "graduationcap.fill"
        case .library: return "star.fill"
        }
    }

    /// ⌘1 … ⌘6
    var shortcut: KeyEquivalent {
        let position = (AppSection.allCases.firstIndex(of: self) ?? 0) + 1
        return KeyEquivalent(Character(String(position)))
    }
}

/// Holds the loaded chemistry data and the app-wide navigation state.
@Observable
final class AppModel {
    enum LoadState: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    private(set) var elements: [Element] = []
    private(set) var terms: [Term] = []
    private(set) var termsByID: [String: Term] = [:]
    private(set) var elementsByID: [Int: Element] = [:]
    private(set) var elementsBySymbol: [String: Element] = [:]
    private(set) var knownSymbols: Set<String> = []
    private(set) var maxRow = 0
    private(set) var maxColumn = 0
    private(set) var emptyRows: Set<Int> = []
    private(set) var loadState: LoadState = .idle

    var section: AppSection = .dictionary
    var selectedTermID: Term.ID?
    var selectedElementID: Element.ID?
    var isPaletteVisible = false

    let dictionary = DictionaryModel()

    @ObservationIgnored private var positions: [Int: Element] = [:]

    // MARK: Loading

    func load() async {
        switch loadState {
        case .loading, .loaded: return
        case .idle, .failed: break
        }
        loadState = .loading

        do {
            async let loadedElements = DataLoader.loadElements()
            async let loadedTerms = DataLoader.loadTerms()
            let (newElements, newTerms) = try await (loadedElements, loadedTerms)

            elements = newElements.sorted { $0.id < $1.id }
            terms = newTerms
            termsByID = Dictionary(newTerms.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            elementsByID = Dictionary(elements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            elementsBySymbol = Dictionary(elements.map { ($0.symbol, $0) }, uniquingKeysWith: { first, _ in first })
            knownSymbols = Set(elements.map(\.symbol))

            maxRow = elements.map(\.row).max() ?? 0
            maxColumn = elements.map(\.column).max() ?? 0
            positions = Dictionary(elements.map { ($0.row * 100 + $0.column, $0) }, uniquingKeysWith: { first, _ in first })
            let occupiedRows = Set(elements.map(\.row))
            emptyRows = Set((1...max(maxRow, 1)).filter { !occupiedRows.contains($0) })

            dictionary.configure(terms: newTerms)
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func retry() async {
        if case .failed = loadState { loadState = .idle }
        await load()
    }

    // MARK: Lookup & navigation

    func element(row: Int, column: Int) -> Element? { positions[row * 100 + column] }

    func open(term id: Term.ID) {
        dictionary.resetFilters()
        selectedTermID = id
        section = .dictionary
        isPaletteVisible = false
    }

    func open(element id: Element.ID) {
        selectedElementID = id
        section = .elements
        isPaletteVisible = false
    }
}
