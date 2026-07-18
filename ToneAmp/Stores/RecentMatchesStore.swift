import Foundation
import Observation

/// A song the user identified with Shazam — kept so Identify has a history.
struct RecentMatch: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let artworkURLString: String?
    let date: Date

    var artworkURL: URL? {
        guard let artworkURLString else { return nil }
        return URL(string: artworkURLString)
    }
}

@Observable
final class RecentMatchesStore {
    private static let defaultsKey = "toneamp.recentMatches"

    private(set) var matches: [RecentMatch]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([RecentMatch].self, from: data) {
            matches = saved
        } else {
            matches = []
        }
    }

    func add(title: String, artist: String, artworkURL: URL?) {
        // Dedupe on title+artist, newest first, capped at 10.
        matches.removeAll {
            $0.title.caseInsensitiveCompare(title) == .orderedSame
                && $0.artist.caseInsensitiveCompare(artist) == .orderedSame
        }
        matches.insert(
            RecentMatch(
                id: UUID(),
                title: title,
                artist: artist,
                artworkURLString: artworkURL?.absoluteString,
                date: Date()
            ),
            at: 0
        )
        matches = Array(matches.prefix(10))
        persist()
    }

    func clear() {
        matches = []
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(matches) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
