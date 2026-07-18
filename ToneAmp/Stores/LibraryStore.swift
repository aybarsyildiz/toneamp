import Foundation
import Observation

@Observable
final class LibraryStore {
    private(set) var songs: [Song]
    private var didLoadArtwork = false
    private static let artworkCacheKey = "toneamp.artworkCache"

    init(songs: [Song] = SongCatalog.songs) {
        let cache = UserDefaults.standard.dictionary(forKey: Self.artworkCacheKey) as? [String: String] ?? [:]
        var merged = songs
        var seenIDs = Set(songs.map { $0.id })
        // The generated seed catalog (1000+ songs with iTunes artwork) ships
        // as a bundled resource; hand-checked compiled songs win on conflict.
        if let url = Bundle.main.url(forResource: "SeedCatalog", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let seed = try? JSONDecoder().decode([Song].self, from: data) {
            for song in seed where !seenIDs.contains(song.id) {
                seenIDs.insert(song.id)
                merged.append(song)
            }
        }
        self.songs = merged
            .map { song in
                guard song.artworkURL == nil,
                      let cached = cache[song.id],
                      let url = URL(string: cached) else {
                    return song
                }
                return song.withArtwork(url)
            }
            .sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    /// Fills in album artwork for curated songs from the iTunes catalog.
    /// Runs once per install (results cached in UserDefaults), paced to
    /// stay under the iTunes Search API rate limit.
    @MainActor
    func loadArtworkIfNeeded() async {
        guard !didLoadArtwork else { return }
        didLoadArtwork = true

        var cache = UserDefaults.standard.dictionary(forKey: Self.artworkCacheKey) as? [String: String] ?? [:]
        // Cap per launch to stay friendly with the iTunes API rate limit —
        // seed songs already ship with artwork; this catches stragglers.
        let missing = songs.filter { $0.artworkURL == nil }.prefix(60)
        for song in missing {
            guard cache[song.id] == nil else { continue }
            let results = try? await MusicSearchService.search("\(song.title) \(song.artist)")
            if let url = results?.first?.largeArtworkURL {
                cache[song.id] = url.absoluteString
                UserDefaults.standard.set(cache, forKey: Self.artworkCacheKey)
                if let index = songs.firstIndex(where: { $0.id == song.id }) {
                    songs[index] = songs[index].withArtwork(url)
                }
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    func song(id: String) -> Song? {
        songs.first { $0.id == id }
    }

    /// Hand-picked shelf for the Library landing screen — a spread of
    /// characters (clean, fuzz, high gain…) rather than a popularity list.
    var featuredSongs: [Song] {
        let ids = [
            "comfortably-numb",
            "purple-haze",
            "enter-sandman",
            "sultans-of-swing",
            "seven-nation-army",
        ]
        return ids.compactMap { song(id: $0) }
    }

    func songs(matching query: String, genre: Genre?) -> [Song] {
        var result = songs
        if let genre {
            result = result.filter { $0.genre == genre }
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return result }
        return result.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.artist.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Fuzzy-matches a ShazamKit media item against the catalog.
    /// Titles are compared after normalization so "Sweet Child O' Mine
    /// (Remastered)" still hits — but a known artist must ALWAYS verify:
    /// "Bottom" by TOOL must never resolve to "Bell Bottom Blues".
    func match(title: String?, artist: String?) -> Song? {
        guard let title, !title.isEmpty else { return nil }
        let normalizedTitle = Self.normalize(title)
        guard !normalizedTitle.isEmpty else { return nil }
        let normalizedArtist = Self.normalize(artist ?? "")

        func artistMatches(_ song: Song) -> Bool {
            guard !normalizedArtist.isEmpty else { return true }
            let candidate = Self.normalize(song.artist)
            return candidate == normalizedArtist
                || candidate.contains(normalizedArtist)
                || normalizedArtist.contains(candidate)
        }

        // Exact title (artist-verified when an artist is known).
        if let exact = songs.first(where: {
            Self.normalize($0.title) == normalizedTitle && artistMatches($0)
        }) {
            return exact
        }

        // Partial titles only cover edition suffixes ("… (Live)", "… - Remastered"):
        // they require a verified artist AND a distinctive overlap length.
        guard !normalizedArtist.isEmpty else { return nil }
        return songs.first { song in
            let candidate = Self.normalize(song.title)
            let contains = candidate.contains(normalizedTitle) || normalizedTitle.contains(candidate)
            let shorterLength = min(candidate.count, normalizedTitle.count)
            return contains && shorterLength >= 8 && artistMatches(song)
        }
    }

    static func normalize(_ string: String) -> String {
        let folded = string.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: nil
        )
        return folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
