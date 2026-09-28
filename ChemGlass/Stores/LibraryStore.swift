import Foundation
import Observation

/// The user's favourites, recently viewed items and notes, persisted as JSON in Application Support.
@Observable
final class LibraryStore {
    private(set) var favoriteTermIDs: Set<String> = []
    private(set) var favoriteElementIDs: Set<Int> = []
    private(set) var recentTermIDs: [String] = []
    private(set) var recentElementIDs: [Int] = []
    private(set) var notes: [String: String] = [:]

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private let fileURL: URL

    nonisolated private struct Snapshot: Codable {
        var favoriteTerms: [String] = []
        var favoriteElements: [Int] = []
        var recentTerms: [String] = []
        var recentElements: [Int] = []
        var notes: [String: String] = [:]
    }

    private static let recentLimit = 30

    init() {
        let directory = URL.applicationSupportDirectory.appending(path: "ChemGlass", directoryHint: .isDirectory)
        fileURL = directory.appending(path: "library.json")
        load()
    }

    // MARK: Favourites

    func toggleFavorite(term id: String) {
        if favoriteTermIDs.contains(id) { favoriteTermIDs.remove(id) } else { favoriteTermIDs.insert(id) }
        scheduleSave()
    }

    func toggleFavorite(element id: Int) {
        if favoriteElementIDs.contains(id) { favoriteElementIDs.remove(id) } else { favoriteElementIDs.insert(id) }
        scheduleSave()
    }

    // MARK: Notes

    func note(forTerm id: String) -> String { notes[id] ?? "" }

    func setNote(_ text: String, forTerm id: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes.removeValue(forKey: id)
        } else {
            notes[id] = text
        }
        scheduleSave()
    }

    // MARK: Recents

    func recordView(ofTerm id: String) {
        guard recentTermIDs.first != id else { return }
        recentTermIDs.removeAll { $0 == id }
        recentTermIDs.insert(id, at: 0)
        if recentTermIDs.count > Self.recentLimit { recentTermIDs.removeLast(recentTermIDs.count - Self.recentLimit) }
        scheduleSave()
    }

    func recordView(ofElement id: Int) {
        guard recentElementIDs.first != id else { return }
        recentElementIDs.removeAll { $0 == id }
        recentElementIDs.insert(id, at: 0)
        if recentElementIDs.count > Self.recentLimit { recentElementIDs.removeLast(recentElementIDs.count - Self.recentLimit) }
        scheduleSave()
    }

    func clearRecents() {
        recentTermIDs = []
        recentElementIDs = []
        scheduleSave()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        favoriteTermIDs = Set(snapshot.favoriteTerms)
        favoriteElementIDs = Set(snapshot.favoriteElements)
        recentTermIDs = snapshot.recentTerms
        recentElementIDs = snapshot.recentElements
        notes = snapshot.notes
    }

    /// Coalesces bursts of edits (e.g. typing a note) into a single write.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.writeToDisk()
        }
    }

    private func writeToDisk() {
        let snapshot = Snapshot(
            favoriteTerms: favoriteTermIDs.sorted(),
            favoriteElements: favoriteElementIDs.sorted(),
            recentTerms: recentTermIDs,
            recentElements: recentElementIDs,
            notes: notes
        )
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ChemGlass: could not save library – \(error.localizedDescription)")
        }
    }
}
