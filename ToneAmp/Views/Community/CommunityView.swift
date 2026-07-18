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

    /// Browse is song-level: one row per song no matter how many tones it
    /// has — the song page ranks the individual tones.
    private var songSummaries: [CommunitySongSummary] {
        recentTones.groupedBySong()
    }

    private var topSongs: [CommunitySongSummary] {
        songSummaries
            .filter { $0.bestAverage != nil }
            .sorted { ($0.bestAverage ?? 0) > ($1.bestAverage ?? 0) }
    }

    private var recentSongs: [CommunitySongSummary] {
        songSummaries.sorted { $0.latest > $1.latest }
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
                if !topSongs.isEmpty {
                    Section("Top Rated") {
                        ForEach(topSongs.prefix(10)) { summary in
                            NavigationLink(value: summary.song) {
                                CommunitySongRow(summary: summary)
                            }
                        }
                    }
                }
                Section("Recently Active") {
                    ForEach(recentSongs) { summary in
                        NavigationLink(value: summary.song) {
                            CommunitySongRow(summary: summary)
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

/// One song in the browse feed, its tones rolled up into a count + rating.
struct CommunitySongRow: View {
    let summary: CommunitySongSummary

    var body: some View {
        HStack(spacing: 12) {
            SongArtworkView(genre: summary.song.genre, artworkURL: summary.song.artworkURL, size: 52)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.song.trackName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(summary.song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(summary.toneCount == 1 ? "1 tone" : "\(summary.toneCount) tones")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(.secondary)
                    if summary.bestAverage != nil {
                        RatingSummaryLabel(average: summary.bestAverage, count: summary.ratingCount)
                    }
                }
            }
        }
        .padding(.vertical, 3)
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
