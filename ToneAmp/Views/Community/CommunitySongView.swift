import SwiftUI

/// One canonical song (from the iTunes catalog) and every tone the
/// community has published for it.
struct CommunitySongView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AIToneCacheStore.self) private var aiCache
    @Environment(ModerationStore.self) private var moderation
    let song: CatalogSong

    @State private var tones: [CommunityTone] = []
    @State private var isLoading = true

    private var visibleTones: [CommunityTone] {
        tones.filter { !moderation.isHidden($0) }
    }
    @State private var errorMessage: String?
    @State private var showingEditor = false
    @State private var showingAIFinder = false
    @State private var showingProTeaser = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    SongArtworkView(genre: song.genre, artworkURL: song.largeArtworkURL, size: 160)
                        .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                    VStack(spacing: 3) {
                        Text(song.trackName)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text(song.artistName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        if let album = song.collectionName {
                            Text(song.year > 0 ? "\(album) · \(String(song.year))" : album)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            if !aiCache.tones(forTrackID: song.trackId).isEmpty {
                Section("Your AI Tones") {
                    ForEach(aiCache.tones(forTrackID: song.trackId)) { saved in
                        NavigationLink(value: saved) {
                            SavedAIToneRow(tone: saved, showSong: false)
                        }
                    }
                }
            }

            Section("Community Tones") {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "icloud.slash")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if visibleTones.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.tint)
                            .symbolEffect(.pulse)
                        Text("No tones yet — be the first to publish one.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(visibleTones) { tone in
                        NavigationLink(value: tone) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(tone.toneName)
                                    Spacer()
                                    CharacterBadge(character: tone.character)
                                }
                                HStack(spacing: 8) {
                                    RatingSummaryLabel(average: tone.averageRating, count: tone.ratingCount)
                                    Text("by \(tone.authorName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            Section {
                VStack(spacing: 10) {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Add Your Tone", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        if session.isPro {
                            showingAIFinder = true
                        } else {
                            showingProTeaser = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                            Text("Identify Tones")
                            Text("PRO")
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.white.opacity(0.22), in: Capsule())
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle(song.trackName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: CommunityTone.self) { tone in
            CommunityToneDetailView(tone: tone)
        }
        .navigationDestination(for: SavedAITone.self) { saved in
            SavedAIToneDetailView(tone: saved)
        }
        .sheet(isPresented: $showingEditor) {
            ToneEditorView(song: song) {
                Task { await load() }
            }
        }
        .sheet(isPresented: $showingAIFinder) {
            AIToneFinderView(song: song) {
                Task { await load() }
            }
        }
        .fullScreenCover(isPresented: $showingProTeaser) {
            ProPaywallView()
        }
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            tones = try await CommunityService.tones(forTrackID: song.trackId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
