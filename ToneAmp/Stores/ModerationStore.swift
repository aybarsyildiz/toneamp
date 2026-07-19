import Foundation
import Observation

/// Local moderation of community content — App Review requires that users
/// can hide objectionable content and block its authors, effective
/// immediately and without a server round-trip.
@Observable
final class ModerationStore {
    private static let hiddenKey = "toneamp.hiddenToneIDs"
    private static let blockedKey = "toneamp.blockedAuthorIDs"

    private(set) var hiddenToneIDs: Set<String>
    private(set) var blockedAuthorIDs: Set<String>

    init() {
        hiddenToneIDs = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
        blockedAuthorIDs = Set(UserDefaults.standard.stringArray(forKey: Self.blockedKey) ?? [])
    }

    func isHidden(_ tone: CommunityTone) -> Bool {
        hiddenToneIDs.contains(tone.id)
            || (!tone.authorID.isEmpty && blockedAuthorIDs.contains(tone.authorID))
    }

    func hide(toneID: String) {
        hiddenToneIDs.insert(toneID)
        persist()
    }

    func block(authorID: String) {
        guard !authorID.isEmpty else { return }
        blockedAuthorIDs.insert(authorID)
        persist()
    }

    func unhideAll() {
        hiddenToneIDs = []
        blockedAuthorIDs = []
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(hiddenToneIDs), forKey: Self.hiddenKey)
        UserDefaults.standard.set(Array(blockedAuthorIDs), forKey: Self.blockedKey)
    }
}
