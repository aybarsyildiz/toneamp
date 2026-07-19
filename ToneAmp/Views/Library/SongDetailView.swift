import SwiftUI

struct SongDetailView: View {
    @Environment(FavoritesStore.self) private var favorites
    @Environment(SessionStore.self) private var session
    let song: Song

    @State private var favoriteToggleCount = 0

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    SongArtworkView(genre: song.genre, artworkURL: song.artworkURL, size: 160)
                        .shadow(color: song.genre.tint.opacity(0.35), radius: 18, y: 10)
                    VStack(spacing: 3) {
                        Text(song.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(song.artist)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("\(song.album) · \(String(song.year))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(song.genre.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(song.genre.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(song.genre.tint)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Tones") {
                ForEach(song.tones) { tone in
                    NavigationLink(value: tone) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(tone.name)
                                Spacer()
                                CharacterBadge(character: tone.character)
                            }
                            Text(tone.amp)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Tone.self) { tone in
            ToneDetailView(tone: tone, song: song)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard session.requireSignIn() else { return }
                    favorites.toggle(song)
                    favoriteToggleCount += 1
                } label: {
                    Image(systemName: favorites.isFavorite(song) ? "star.fill" : "star")
                        .symbolEffect(.bounce, value: favoriteToggleCount)
                }
                .accessibilityLabel(
                    favorites.isFavorite(song) ? "Remove from Favorites" : "Add to Favorites"
                )
            }
        }
        .sensoryFeedback(.selection, trigger: favoriteToggleCount)
    }
}
