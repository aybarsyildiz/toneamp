import SwiftUI
import UIKit

struct IdentifyView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(\.openURL) private var openURL
    @State private var matcher = ShazamMatcher()
    @State private var recents = RecentMatchesStore()
    @State private var path = NavigationPath()
    @State private var isFindingTone = false
    @State private var findErrorMessage: String?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if matcher.state == .denied {
                    deniedView
                } else {
                    listenView
                }
            }
            .navigationTitle("Identify")
            .navigationDestination(for: Song.self) { song in
                SongDetailView(song: song)
            }
            .navigationDestination(for: CatalogSong.self) { song in
                CommunitySongView(song: song)
            }
        }
        .sensoryFeedback(.success, trigger: matchedTitle)
        .onChange(of: matcher.state) { _, newState in
            if case .matched(let match) = newState {
                recents.add(title: match.title, artist: match.artist, artworkURL: match.artworkURL)
            }
        }
        .onDisappear {
            if matcher.isListening {
                matcher.cancel()
            }
        }
    }

    private func resolvedSong(for match: ShazamMatcher.MatchedSong) -> Song? {
        if let song = match.catalogSong {
            return library.song(id: song.id) ?? song
        }
        return library.match(title: match.title, artist: match.artist)
    }

    /// Looks a song up in the iTunes catalog and opens its community page —
    /// where its published tones (if any) live.
    private func findInCommunity(title: String, artist: String) {
        guard !isFindingTone else { return }
        isFindingTone = true
        findErrorMessage = nil
        Task { @MainActor in
            let results = try? await MusicSearchService.search("\(title) \(artist)")
            if let first = results?.first {
                path.append(first)
            } else {
                findErrorMessage = "Couldn't find this song in the catalog."
            }
            isFindingTone = false
        }
    }

    private var matchedTitle: String? {
        if case .matched(let match) = matcher.state {
            return match.title
        }
        return nil
    }

    private var statusText: String {
        switch matcher.state {
        case .idle:
            return "Tap to hear what's playing\nand find its guitar tone."
        case .listening:
            return "Listening…"
        case .matched(let match):
            return "\(match.title) — \(match.artist)"
        case .noMatch:
            return "No match. Get closer to the\nspeaker and try again."
        case .denied:
            return ""
        case .failed:
            return "Couldn't identify the song."
        }
    }

    private var listenView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                if matcher.isListening {
                    PulsingRings()
                }
                Button {
                    matcher.toggle(library: library)
                } label: {
                    Image(systemName: "shazam.logo.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.white)
                        .symbolEffect(
                            .variableColor.iterative.reversing,
                            isActive: matcher.isListening
                        )
                        .frame(width: 132, height: 132)
                        .background(Circle().fill(Color.accentColor.gradient))
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(matcher.isListening ? "Stop listening" : "Identify song")
            }
            .frame(height: 220)
            Text(statusText)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if case .failed(let failure) = matcher.state {
                VStack(spacing: 6) {
                    Text("Make sure your iPhone is connected to the internet, then tap to try again.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("\(failure.message) [\(failure.diagnostic)]")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            }
            Spacer()
            if matcher.state == .idle && !recents.matches.isEmpty {
                recentsList
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                resultCard
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: matcher.state)
    }

    private var recentsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    withAnimation {
                        recents.clear()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            ForEach(recents.matches.prefix(3)) { match in
                Button {
                    findInCommunity(title: match.title, artist: match.artist)
                } label: {
                    HStack(spacing: 10) {
                        Group {
                            if let url = match.artworkURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    default:
                                        Color(.tertiarySystemFill)
                                    }
                                }
                            } else {
                                Color(.tertiarySystemFill)
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(match.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(match.artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        switch matcher.state {
        case .matched(let match):
            if let song = resolvedSong(for: match) {
                NavigationLink(value: song) {
                    MatchResultCard(match: match, hasTone: true)
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 10) {
                    MatchResultCard(match: match, hasTone: false)
                    Button {
                        findInCommunity(title: match.title, artist: match.artist)
                    } label: {
                        Group {
                            if isFindingTone {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("Opening…")
                                }
                            } else {
                                Label("Find in Community", systemImage: "person.3.fill")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isFindingTone)
                    if let findErrorMessage {
                        Text(findErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("Microphone Access Needed", systemImage: "mic.slash")
        } description: {
            Text("ToneAmp needs the microphone to hear what's playing. You can enable it in Settings.")
        } actions: {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct MatchResultCard: View {
    let match: ShazamMatcher.MatchedSong
    let hasTone: Bool

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 2) {
                Text(match.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(match.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if hasTone {
                    Text("View tones")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                } else {
                    Text("No tone for this one yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if hasTone {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    @ViewBuilder
    private var artwork: some View {
        if let url = match.artworkURL {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.tertiarySystemFill)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

private struct PulsingRings: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 2)
                    .frame(width: 132, height: 132)
                    .scaleEffect(animate ? 1.7 : 1)
                    .opacity(animate ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: 2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.6),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}
