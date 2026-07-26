import AVFoundation
import Observation
import SwiftUI

/// Plays the song's official 30-second preview (Apple's catalog) so players
/// can A/B their amp against the record while dialing the tone in.
@Observable
final class ReferencePlayer {
    static let shared = ReferencePlayer()

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    /// Track ID currently playing (nil when idle).
    private(set) var playingID: Int?
    private(set) var isLoading = false

    func toggle(trackID: Int, url: URL) {
        if playingID == trackID {
            stop()
            return
        }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
        self.player = player
        playingID = trackID
        player.play()
    }

    func stop() {
        player?.pause()
        player = nil
        playingID = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}

/// "Hear the record" chip. Resolves the preview URL lazily via the iTunes
/// catalog when one wasn't already known, then streams it.
struct ReferencePlayButton: View {
    let trackID: Int
    let songTitle: String
    let artist: String
    var knownPreviewURL: String? = nil

    @State private var player = ReferencePlayer.shared
    @State private var resolving = false
    @State private var resolvedURL: URL?
    @State private var unavailable = false

    private var isPlaying: Bool {
        player.playingID == trackID
    }

    var body: some View {
        if unavailable {
            EmptyView()
        } else {
            Button {
                Task { await tap() }
            } label: {
                HStack(spacing: 6) {
                    if resolving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.caption)
                            .symbolEffect(.pulse, isActive: isPlaying)
                    }
                    Text(isPlaying ? "Stop" : "Hear the Record")
                        .font(.footnote.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.accentColor.opacity(0.14), in: Capsule())
                .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isPlaying)
        }
    }

    @MainActor
    private func tap() async {
        if let resolvedURL {
            player.toggle(trackID: trackID, url: resolvedURL)
            return
        }
        if let known = knownPreviewURL, let url = URL(string: known) {
            resolvedURL = url
            player.toggle(trackID: trackID, url: url)
            return
        }
        resolving = true
        defer { resolving = false }
        let match = try? await MusicSearchService.searchSong(title: songTitle, artist: artist)
        guard let preview = match?.previewUrl, let url = URL(string: preview) else {
            unavailable = true
            return
        }
        resolvedURL = url
        player.toggle(trackID: trackID, url: url)
    }
}
