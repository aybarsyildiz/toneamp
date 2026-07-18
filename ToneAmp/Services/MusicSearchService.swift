import Foundation

/// A canonical song from the iTunes Search API — the source of truth for
/// song identity in the community. Free, no API key, includes artwork.
struct CatalogSong: Codable, Hashable, Identifiable {
    let trackId: Int
    let trackName: String
    let artistName: String
    let collectionName: String?
    let releaseDate: String?
    let primaryGenreName: String?
    let artworkUrl100: String?

    var id: Int { trackId }

    var year: Int {
        guard let releaseDate, releaseDate.count >= 4,
              let value = Int(releaseDate.prefix(4)) else {
            return 0
        }
        return value
    }

    var artworkURL: URL? {
        guard let artworkUrl100 else { return nil }
        return URL(string: artworkUrl100)
    }

    /// iTunes serves any square size by rewriting the path.
    var largeArtworkURL: URL? {
        guard let artworkUrl100 else { return nil }
        return URL(string: artworkUrl100.replacingOccurrences(of: "100x100", with: "600x600"))
    }

    /// Maps iTunes' free-form genre names onto the app's genre set.
    var genre: Genre {
        let name = (primaryGenreName ?? "").lowercased()
        if name.contains("metal") { return .metal }
        if name.contains("grunge") { return .grunge }
        if name.contains("blues") { return .bluesRock }
        if name.contains("alternative") || name.contains("indie") { return .alternative }
        if name.contains("funk") { return .funkRock }
        if name.contains("psych") { return .psychedelic }
        if name.contains("hard rock") { return .hardRock }
        return .rock
    }
}

enum MusicSearchError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "The song catalog is unavailable right now. Try again."
        }
    }
}

enum MusicSearchService {
    private struct SearchResponse: Decodable {
        let results: [CatalogSong]
    }

    /// Finds one specific recording: results are scored by artist match
    /// first (covers and tribute albums rank high in raw text search), then
    /// title exactness. Returns nil rather than a wrong-artist result.
    static func searchSong(title: String, artist: String) async throws -> CatalogSong? {
        let results = try await search("\(title) \(artist)")
        let targetTitle = LibraryStore.normalize(title)
        let targetArtist = LibraryStore.normalize(artist)

        func score(_ song: CatalogSong) -> Int {
            let candidateTitle = LibraryStore.normalize(song.trackName)
            let candidateArtist = LibraryStore.normalize(song.artistName)
            var total = 0
            if candidateArtist == targetArtist {
                total += 100
            } else if candidateArtist.contains(targetArtist) || targetArtist.contains(candidateArtist) {
                total += 60
            } else {
                return 0 // wrong artist — never acceptable
            }
            if candidateTitle == targetTitle {
                total += 50
            } else if candidateTitle.contains(targetTitle) || targetTitle.contains(candidateTitle) {
                total += 20
            }
            return total
        }

        return results
            .map { (song: $0, score: score($0)) }
            .filter { $0.score >= 60 }
            .max { $0.score < $1.score }?
            .song
    }

    static func search(_ term: String) async throws -> [CatalogSong] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: trimmed),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "25"),
        ]
        guard let url = components.url else {
            throw MusicSearchError.badResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw MusicSearchError.badResponse
        }
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)

        // iTunes returns many editions of the same recording — keep the first
        // of each (title, artist) pair.
        var seen = Set<String>()
        var unique: [CatalogSong] = []
        for song in decoded.results {
            let key = LibraryStore.normalize(song.trackName + "|" + song.artistName)
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(song)
            }
        }
        return unique
    }
}
