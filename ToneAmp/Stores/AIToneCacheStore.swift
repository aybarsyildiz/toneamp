import Foundation
import Observation

/// A Pro-generated tone, saved locally for the user — bound to the exact
/// song and the rig it was generated for.
struct SavedAITone: Codable, Identifiable, Hashable {
    let id: UUID
    let trackID: Int
    let songTitle: String
    let artistName: String
    let albumName: String
    let year: Int
    let genreRaw: String
    let artworkURLString: String?
    let createdAt: Date
    let name: String
    let characterRaw: String
    let ampName: String
    let settings: AmpSettings
    let guitar: String
    let pickup: String
    let pedals: [EffectPedal]
    let notes: String
    let rigTips: [String]
    let rigDescription: String

    var character: ToneCharacter {
        ToneCharacter(rawValue: characterRaw) ?? .crunch
    }

    var genre: Genre {
        Genre(rawValue: genreRaw) ?? .rock
    }

    var artworkURL: URL? {
        guard let artworkURLString else { return nil }
        return URL(string: artworkURLString)
    }

    /// Lets a saved tone republish or deep-link like any catalog song.
    var asCatalogSong: CatalogSong {
        CatalogSong(
            trackId: trackID,
            trackName: songTitle,
            artistName: artistName,
            collectionName: albumName.isEmpty ? nil : albumName,
            releaseDate: year > 0 ? "\(year)-01-01" : nil,
            primaryGenreName: genreRaw,
            artworkUrl100: artworkURLString
        )
    }
}

/// Persists every Pro "Identify Tones" result to disk — the user's private
/// library of AI-generated, rig-specific tone sheets.
@Observable
final class AIToneCacheStore {
    private(set) var tones: [SavedAITone]

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ai-tones.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let saved = try? JSONDecoder().decode([SavedAITone].self, from: data) {
            tones = saved
        } else {
            tones = []
        }
    }

    func save(_ generated: [AIGeneratedTone], for song: CatalogSong, rigDescription: String) {
        for tone in generated {
            // Regenerating replaces the previous version of the same tone.
            tones.removeAll { $0.trackID == song.trackId && $0.name == tone.name }
            tones.insert(
                SavedAITone(
                    id: UUID(),
                    trackID: song.trackId,
                    songTitle: song.trackName,
                    artistName: song.artistName,
                    albumName: song.collectionName ?? "",
                    year: song.year,
                    genreRaw: song.genre.rawValue,
                    artworkURLString: (song.largeArtworkURL ?? song.artworkURL)?.absoluteString,
                    createdAt: Date(),
                    name: tone.name,
                    characterRaw: tone.character.rawValue,
                    ampName: tone.ampName,
                    settings: tone.settings,
                    guitar: tone.guitar,
                    pickup: tone.pickup,
                    pedals: tone.pedals,
                    notes: tone.notes,
                    rigTips: tone.rigTips,
                    rigDescription: rigDescription
                ),
                at: 0
            )
        }
        persist()
    }

    func tones(forTrackID trackID: Int) -> [SavedAITone] {
        tones.filter { $0.trackID == trackID }
    }

    func delete(_ tone: SavedAITone) {
        tones.removeAll { $0.id == tone.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(tones) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}
