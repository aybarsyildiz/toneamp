import AVFoundation
import Foundation
import Observation
import ShazamKit

/// Wraps `SHManagedSession` (iOS 17+) behind a small state machine the
/// Identify screen can render directly. All system side effects — mic
/// permission, audio capture, Shazam catalog matching — live here.
@MainActor
@Observable
final class ShazamMatcher {
    enum State: Equatable {
        case idle
        case listening
        case matched(MatchedSong)
        case noMatch
        case denied
        case failed(FailureDetail)
    }

    /// Keeps the raw error visible to the user/tester — "something went
    /// wrong" without the domain and code is undebuggable in the field.
    struct FailureDetail: Equatable {
        let message: String
        let diagnostic: String
    }

    struct MatchedSong: Equatable {
        let title: String
        let artist: String
        let artworkURL: URL?
        let catalogSong: Song?
    }

    private(set) var state: State = .idle

    private let session = SHManagedSession()
    private var matchTask: Task<Void, Never>?

    var isListening: Bool {
        state == .listening
    }

    func toggle(library: LibraryStore) {
        if isListening {
            cancel()
        } else {
            start(library: library)
        }
    }

    func start(library: LibraryStore) {
        cancelTask()
        matchTask = Task {
            await self.listen(library: library)
        }
    }

    func cancel() {
        cancelTask()
        session.cancel()
        state = .idle
    }

    private func cancelTask() {
        matchTask?.cancel()
        matchTask = nil
    }

    private func listen(library: LibraryStore) async {
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            state = .denied
            return
        }
        guard !Task.isCancelled else { return }

        state = .listening
        await session.prepare()
        guard !Task.isCancelled else { return }
        let result = await session.result()
        session.cancel()
        guard !Task.isCancelled else { return }

        switch result {
        case .match(let match):
            if let item = match.mediaItems.first {
                state = .matched(
                    MatchedSong(
                        title: item.title ?? "Unknown Song",
                        artist: item.artist ?? "Unknown Artist",
                        artworkURL: item.artworkURL,
                        catalogSong: library.match(title: item.title, artist: item.artist)
                    )
                )
            } else {
                state = .noMatch
            }
        case .noMatch:
            state = .noMatch
        case .error(let error, _):
            let nsError = error as NSError
            print("[ToneAmp] ShazamKit error: \(nsError)")
            let message: String
            if nsError.domain == "com.apple.ShazamKit" && nsError.code == 202 {
                message = "ShazamKit isn't authorized for this app yet. Enable the ShazamKit app service for the App ID in the Apple Developer portal, then clean-build and reinstall."
            } else {
                message = nsError.localizedDescription
            }
            state = .failed(
                FailureDetail(
                    message: message,
                    diagnostic: "\(nsError.domain) \(nsError.code)"
                )
            )
        }
    }
}
