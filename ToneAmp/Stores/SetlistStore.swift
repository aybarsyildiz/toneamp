import Foundation
import Observation

struct Setlist: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var songIDs: [String] = []
}

/// Named groups of library songs — "Wedding gig", "Practice Tuesday".
/// Local JSON persistence, same pattern as the AI tone cache.
@Observable
final class SetlistStore {
    private(set) var setlists: [Setlist] = []

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("setlists.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([Setlist].self, from: data) {
            setlists = saved
        }
    }

    func create(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        setlists.append(Setlist(name: trimmed))
        persist()
    }

    func delete(_ setlist: Setlist) {
        setlists.removeAll { $0.id == setlist.id }
        persist()
    }

    func toggle(songID: String, in setlistID: UUID) {
        guard let index = setlists.firstIndex(where: { $0.id == setlistID }) else { return }
        if let at = setlists[index].songIDs.firstIndex(of: songID) {
            setlists[index].songIDs.remove(at: at)
        } else {
            setlists[index].songIDs.append(songID)
        }
        persist()
    }

    func contains(songID: String, in setlistID: UUID) -> Bool {
        setlists.first { $0.id == setlistID }?.songIDs.contains(songID) ?? false
    }

    func remove(songID: String, from setlistID: UUID) {
        guard let index = setlists.firstIndex(where: { $0.id == setlistID }) else { return }
        setlists[index].songIDs.removeAll { $0 == songID }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(setlists) {
            try? data.write(to: Self.fileURL)
        }
    }
}
