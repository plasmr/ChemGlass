import Foundation
import Observation

/// Search / filter state for the dictionary. Filtering runs off the main thread and is debounced.
@Observable
final class DictionaryModel {
    var query = ""
    var searchDefinitions = false
    var statusFilter = "All"
    var sortAscending = true
    var favoritesOnly = false

    private(set) var availableStatuses: [String] = ["All"]
    private(set) var sections: [TermSection] = []
    private(set) var resultCount = 0
    private(set) var isFiltering = true

    nonisolated struct Criteria: Hashable, Sendable {
        var query: String
        var searchDefinitions: Bool
        var status: String
        var ascending: Bool
        var favoritesOnly: Bool
        var favoriteIDs: Set<String>
    }

    nonisolated struct FilterResult: Sendable {
        let sections: [TermSection]
        let count: Int
    }

    func configure(terms: [Term]) {
        let statuses = Set(terms.map { $0.status.capitalized }.filter { !$0.isEmpty }).sorted()
        availableStatuses = ["All"] + statuses
    }

    func resetFilters() {
        query = ""
        statusFilter = "All"
        favoritesOnly = false
        sortAscending = true
    }

    /// Re-filters the dictionary. Call from `.task(id:)` so superseded work is cancelled automatically.
    func refresh(terms: [Term], criteria: Criteria) async {
        isFiltering = true
        if !criteria.query.isEmpty {
            try? await Task.sleep(for: .milliseconds(140))
            if Task.isCancelled { return }
        }
        let result = await Self.filter(terms: terms, criteria: criteria)
        if Task.isCancelled { return }
        sections = result.sections
        resultCount = result.count
        isFiltering = false
    }

    @concurrent
    private static func filter(terms: [Term], criteria: Criteria) async -> FilterResult {
        let needle = TextCleaner.fold(criteria.query.trimmingCharacters(in: .whitespacesAndNewlines))

        let matched = terms.filter { term in
            if criteria.status != "All",
               term.status.caseInsensitiveCompare(criteria.status) != .orderedSame { return false }
            if criteria.favoritesOnly, !criteria.favoriteIDs.contains(term.id) { return false }
            if needle.isEmpty { return true }
            if term.titleKey.contains(needle) { return true }
            return criteria.searchDefinitions && term.definitionKey.contains(needle)
        }

        // `terms` is already sorted A→Z, and grouping preserves that order inside each letter.
        let grouped = Dictionary(grouping: matched, by: \.initial)
        var letters = grouped.keys.sorted { lhs, rhs in
            if lhs == "#" { return true }
            if rhs == "#" { return false }
            return lhs < rhs
        }
        if !criteria.ascending { letters.reverse() }

        let sections = letters.map { letter -> TermSection in
            let members = grouped[letter] ?? []
            return TermSection(id: letter, terms: criteria.ascending ? members : Array(members.reversed()))
        }
        return FilterResult(sections: sections, count: matched.count)
    }
}
