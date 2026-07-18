import SwiftUI

/// Community home: search Apple's song catalog, or browse top-rated and
/// recent tones published by other players.
struct CommunityView: View {
    @State private var searchText = ""
    @State private var searchResults: [CatalogSong] = []
    @State private var recentTones: [CommunityTone] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var topTones: [CommunityTone] {
        recentTones
            .filter { $0.ratingCount > 0 }
            .sorted { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    searchResultsList
                } else {
                    browseList
                }
            }
            .navigationTitle("Community")
            .searchable(text: $searchText, prompt: "Search any song")
            .navigationDestination(for: CatalogSong.self) { song in
                CommunitySongView(song: song)
            }
            .navigationDestination(for: CommunityTone.self) { tone in
                CommunityToneDetailView(tone: tone)
            }
            .task {
                await loadTones()
            }
            .task(id: searchText) {
                await runSearch()
            }
            .refreshable {
                await loadTones()
            }
        }
    }

    private var searchResultsList: some View {
        List(searchResults) { song in
            NavigationLink(value: song) {
                CatalogSongRow(song: song)
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if searchResults.isEmpty && !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    @ViewBuilder
    private var browseList: some View {
        if let errorMessage {
            ContentUnavailableView {
                Label("Community Unavailable", systemImage: "icloud.slash")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await loadTones() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if recentTones.isEmpty {
            if isLoading {
                ProgressView("Loading community tones…")
            } else {
                ContentUnavailableView {
                    Label("No Tones Yet", systemImage: "music.note.list")
                } description: {
                    Text("Search a song above and be the first to publish its tone.")
                }
            }
        } else {
            List {
                if !topTones.isEmpty {
                    Section("Top Rated") {
                        ForEach(topTones.prefix(10)) { tone in
                            NavigationLink(value: tone) {
                                CommunityToneRow(tone: tone)
                            }
                        }
                    }
                }
                Section("Recent") {
                    ForEach(recentTones) { tone in
                        NavigationLink(value: tone) {
                            CommunityToneRow(tone: tone)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @MainActor
    private func loadTones() async {
        isLoading = true
        errorMessage = nil
        do {
            recentTones = try await CommunityService.recentTones()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func runSearch() async {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            searchResults = []
            return
        }
        // Debounce keystrokes; task(id:) cancels superseded searches.
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        if let results = try? await MusicSearchService.search(term) {
            searchResults = results
        }
    }
}

struct CatalogSongRow: View {
    let song: CatalogSong

    var body: some View {
        HStack(spacing: 12) {
            SongArtworkView(genre: song.genre, artworkURL: song.artworkURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.trackName)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct CommunityToneRow: View {
    let tone: CommunityTone

    var body: some View {
        HStack(spacing: 12) {
            SongArtworkView(genre: tone.genre, artworkURL: tone.artworkURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(tone.toneName)
                    .lineLimit(1)
                Text("\(tone.songTitle) · \(tone.artistName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                RatingSummaryLabel(average: tone.averageRating, count: tone.ratingCount)
            }
            Spacer()
            CharacterBadge(character: tone.character)
        }
        .padding(.vertical, 2)
    }
}
