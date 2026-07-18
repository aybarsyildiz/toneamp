import SwiftUI

/// Pushed from the Library toolbar (star) — relies on the Library
/// stack's Song navigation destination.
struct FavoritesView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(FavoritesStore.self) private var favorites

    private var songs: [Song] {
        favorites.favoriteSongs(in: library)
    }

    var body: some View {
        Group {
            if songs.isEmpty {
                ContentUnavailableView {
                    Label("No Favorites", systemImage: "star")
                        .symbolEffect(.pulse)
                } description: {
                    Text("Star a song to keep its tone one tap away — swipe right on any song, or tap the star on its page.")
                }
            } else {
                List(songs) { song in
                    NavigationLink(value: song) {
                        SongRow(song: song)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            favorites.toggle(song)
                        } label: {
                            Label("Unfavorite", systemImage: "star.slash.fill")
                        }
                        .tint(.gray)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Favorites")
    }
}
