import Foundation
import Observation
import UIKit

/// The user's profile picture — any image, including Memoji stickers
/// (saved to Photos or copied to the clipboard). Stored locally as PNG
/// (keeps Memoji transparency) and published to the community profile.
@Observable
final class AvatarStore {
    private(set) var imageData: Data?

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatar.png")
    }

    init() {
        imageData = try? Data(contentsOf: Self.fileURL)
    }

    var image: UIImage? {
        guard let imageData else { return nil }
        return UIImage(data: imageData)
    }

    /// Downscales, persists locally, and syncs to the public profile record.
    func set(_ raw: Data, session: SessionStore) {
        guard let scaled = Self.downscale(raw) else { return }
        imageData = scaled
        try? scaled.write(to: Self.fileURL)
        syncToCommunity(session: session)
    }

    func clear(session: SessionStore) {
        imageData = nil
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    func syncToCommunity(session: SessionStore) {
        guard let userID = session.userID else { return }
        let name = session.authorName
        let data = imageData
        Task {
            try? await CommunityService.upsertProfile(
                authorID: userID,
                displayName: name,
                avatarData: data
            )
        }
    }

    private static func downscale(_ data: Data, maxDimension: CGFloat = 256) -> Data? {
        guard let source = UIImage(data: data) else { return nil }
        let largestSide = max(source.size.width, source.size.height)
        let scale = min(1, maxDimension / max(largestSide, 1))
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let scaled = renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.pngData()
    }
}
