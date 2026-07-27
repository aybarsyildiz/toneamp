import Foundation
import Observation

/// Anything that can sit in a setlist: a library song, a published community
/// tone, or one of the user's saved AI tones. Title/subtitle are display
/// snapshots — song and AI-tone rows re-resolve live where possible.
struct SetlistItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case song, community, aiTone
    }

    var kind: Kind
    var id: String
    var title: String
    var subtitle: String
}

extension SetlistItem {
    init(song: Song) {
        self.init(kind: .song, id: song.id, title: song.title, subtitle: song.artist)
    }

    init(community tone: CommunityTone) {
        self.init(
            kind: .community,
            id: tone.id,
            title: tone.toneName,
            subtitle: "\(tone.songTitle) · \(tone.artistName)"
        )
    }

    init(aiTone tone: SavedAITone) {
        self.init(
            kind: .aiTone,
            id: tone.id.uuidString,
            title: tone.name,
            subtitle: "\(tone.songTitle) · \(tone.artistName)"
        )
    }
}

struct Setlist: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var items: [SetlistItem] = []

    init(name: String) {
        self.name = name
    }

    // Early builds stored bare library song IDs; fold them into items on load.
    private enum CodingKeys: String, CodingKey {
        case id, name, items, songIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        items = try container.decodeIfPresent([SetlistItem].self, forKey: .items) ?? []
        if let legacy = try container.decodeIfPresent([String].self, forKey: .songIDs) {
            items += legacy.map { SetlistItem(kind: .song, id: $0, title: "", subtitle: "") }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(items, forKey: .items)
    }
}

/// Named groups of tones — "Wedding gig", "Practice Tuesday".
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

    @discardableResult
    func create(name: String) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let setlist = Setlist(name: trimmed)
        setlists.append(setlist)
        persist()
        return setlist.id
    }

    func delete(_ setlist: Setlist) {
        setlists.removeAll { $0.id == setlist.id }
        persist()
    }

    func add(_ item: SetlistItem, to setlistID: UUID) {
        guard let index = setlists.firstIndex(where: { $0.id == setlistID }),
              !setlists[index].items.contains(where: { $0.id == item.id }) else { return }
        setlists[index].items.append(item)
        persist()
    }

    func toggle(_ item: SetlistItem, in setlistID: UUID) {
        guard let index = setlists.firstIndex(where: { $0.id == setlistID }) else { return }
        if let at = setlists[index].items.firstIndex(where: { $0.id == item.id }) {
            setlists[index].items.remove(at: at)
        } else {
            setlists[index].items.append(item)
        }
        persist()
    }

    func contains(itemID: String, in setlistID: UUID) -> Bool {
        setlists.first { $0.id == setlistID }?.items.contains { $0.id == itemID } ?? false
    }

    func remove(itemID: String, from setlistID: UUID) {
        guard let index = setlists.firstIndex(where: { $0.id == setlistID }) else { return }
        setlists[index].items.removeAll { $0.id == itemID }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(setlists) {
            try? data.write(to: Self.fileURL)
        }
    }
}
