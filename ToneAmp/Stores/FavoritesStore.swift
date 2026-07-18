import Foundation
import Observation

@Observable
final class FavoritesStore {
    private static let defaultsKey = "toneamp.favorites.songIDs"

    private(set) var songIDs: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.songIDs = Set(defaults.stringArray(forKey: Self.defaultsKey) ?? [])
    }

    func isFavorite(_ song: Song) -> Bool {
        songIDs.contains(song.id)
    }

    func toggle(_ song: Song) {
        if songIDs.contains(song.id) {
            songIDs.remove(song.id)
        } else {
            songIDs.insert(song.id)
        }
        defaults.set(Array(songIDs).sorted(), forKey: Self.defaultsKey)
    }

    func favoriteSongs(in library: LibraryStore) -> [Song] {
        library.songs.filter { songIDs.contains($0.id) }
    }
}
