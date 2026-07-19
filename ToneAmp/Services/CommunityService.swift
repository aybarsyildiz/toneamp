import CloudKit
import Foundation

/// A tone published by a community member, backed by a CloudKit record in
/// the public database.
struct CommunityTone: Identifiable, Hashable {
    let id: String
    let trackID: Int
    let songTitle: String
    let artistName: String
    let albumName: String
    let year: Int
    let genre: Genre
    let artworkURL: URL?
    let toneName: String
    let character: ToneCharacter
    let ampName: String
    let settings: AmpSettings
    let guitar: String
    let pickup: String
    let pedals: [EffectPedal]
    let notes: String
    let authorName: String
    let ratingCount: Int
    let ratingTotal: Int
    let createdAt: Date

    var averageRating: Double? {
        guard ratingCount > 0 else { return nil }
        return Double(ratingTotal) / Double(ratingCount)
    }
}

/// Everything needed to publish a new tone.
struct ToneDraft {
    let song: CatalogSong
    let toneName: String
    let character: ToneCharacter
    let ampName: String
    let settings: AmpSettings
    let guitar: String
    let pickup: String
    let pedals: [EffectPedal]
    let notes: String
}

enum CommunityError: LocalizedError {
    case iCloudUnavailable
    case notSignedIn
    case malformedRecord

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "Sign in to iCloud in the Settings app to use community tones."
        case .notSignedIn:
            return "Sign in with Apple to publish and rate tones."
        case .malformedRecord:
            return "The community returned an unexpected response. Try again."
        }
    }
}

/// CloudKit-backed community: publish tones, browse them, rate them.
/// Public database — no server to run; identity comes from iCloud, display
/// names from Sign in with Apple.
enum CommunityService {
    private static let toneRecordType = "PublishedTone"
    private static let ratingRecordType = "ToneRating"

    private static var database: CKDatabase {
        CKContainer.default().publicCloudDatabase
    }

    private static func ensureAccount() async throws {
        let status = try await CKContainer.default().accountStatus()
        guard status == .available else {
            throw CommunityError.iCloudUnavailable
        }
    }

    // MARK: - Browse

    static func tones(forTrackID trackID: Int) async throws -> [CommunityTone] {
        try await ensureAccount()
        let predicate = NSPredicate(format: "trackID == %d", trackID)
        return try await fetchTones(predicate: predicate, limit: 50)
            .sorted { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }
    }

    /// Recent tones across the whole community; callers derive "top rated"
    /// from the same batch client-side.
    static func recentTones(limit: Int = 50) async throws -> [CommunityTone] {
        try await ensureAccount()
        return try await fetchTones(predicate: NSPredicate(format: "trackID > 0"), limit: limit)
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Tones published by one user (the Profile screen).
    static func tones(byAuthorID authorID: String) async throws -> [CommunityTone] {
        try await ensureAccount()
        return try await fetchTones(predicate: NSPredicate(format: "authorID == %@", authorID), limit: 50)
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// No server-side sort descriptors on purpose: sorting by `creationDate`
    /// requires an index fresh containers don't have. Ordering happens
    /// client-side instead, so the community works with zero console setup.
    private static func fetchTones(predicate: NSPredicate, limit: Int) async throws -> [CommunityTone] {
        let query = CKQuery(recordType: toneRecordType, predicate: predicate)
        do {
            let (matchResults, _) = try await database.records(
                matching: query,
                inZoneWith: nil,
                desiredKeys: nil,
                resultsLimit: limit
            )
            return matchResults.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return CommunityTone(record: record)
            }
        } catch let error as CKError {
            switch error.code {
            case .unknownItem, .invalidArguments:
                // The record type doesn't exist until the first tone is
                // published — that's an empty community, not a failure.
                return []
            case .notAuthenticated:
                throw CommunityError.iCloudUnavailable
            default:
                throw error
            }
        }
    }

    // MARK: - Publish

    static func publish(_ draft: ToneDraft, authorName: String, authorID: String) async throws {
        try await ensureAccount()

        let record = CKRecord(recordType: toneRecordType)
        record["trackID"] = draft.song.trackId as CKRecordValue
        record["songTitle"] = draft.song.trackName as CKRecordValue
        record["artistName"] = draft.song.artistName as CKRecordValue
        record["albumName"] = (draft.song.collectionName ?? "") as CKRecordValue
        record["year"] = draft.song.year as CKRecordValue
        record["genre"] = draft.song.genre.rawValue as CKRecordValue
        record["artworkURLString"] = (draft.song.largeArtworkURL?.absoluteString ?? "") as CKRecordValue
        record["toneName"] = draft.toneName as CKRecordValue
        record["character"] = draft.character.rawValue as CKRecordValue
        record["ampName"] = draft.ampName as CKRecordValue
        record["gain"] = draft.settings.gain as CKRecordValue
        record["bass"] = draft.settings.bass as CKRecordValue
        record["mid"] = draft.settings.mid as CKRecordValue
        record["treble"] = draft.settings.treble as CKRecordValue
        record["presence"] = (draft.settings.presence ?? 0) as CKRecordValue
        record["reverb"] = (draft.settings.reverb ?? 0) as CKRecordValue
        record["guitar"] = draft.guitar as CKRecordValue
        record["pickup"] = draft.pickup as CKRecordValue
        record["pedalsJSON"] = pedalsJSON(draft.pedals) as CKRecordValue
        record["notes"] = draft.notes as CKRecordValue
        record["authorName"] = authorName as CKRecordValue
        record["authorID"] = authorID as CKRecordValue
        record["ratingCount"] = 0 as CKRecordValue
        record["ratingTotal"] = 0 as CKRecordValue

        _ = try await database.save(record)
    }

    // MARK: - Ratings

    /// One rating per user per tone: the rating record name is derived from
    /// both IDs, so re-rating overwrites instead of duplicating.
    static func rate(toneID: String, stars: Int, userID: String) async throws {
        try await ensureAccount()
        let clamped = max(1, min(stars, 5))
        let ratingID = CKRecord.ID(recordName: "rating|\(toneID)|\(userID)")

        var previousStars: Int?
        var ratingRecord: CKRecord
        if let existing = try? await database.record(for: ratingID) {
            previousStars = existing["stars"] as? Int
            ratingRecord = existing
        } else {
            ratingRecord = CKRecord(recordType: ratingRecordType, recordID: ratingID)
            ratingRecord["toneRecordName"] = toneID as CKRecordValue
            ratingRecord["raterID"] = userID as CKRecordValue
        }
        ratingRecord["stars"] = clamped as CKRecordValue
        _ = try await database.save(ratingRecord)

        // Update the tone's aggregates. Last-writer-wins is acceptable at
        // MVP scale; a server function replaces this later.
        let toneRecord = try await database.record(for: CKRecord.ID(recordName: toneID))
        let count = toneRecord["ratingCount"] as? Int ?? 0
        let total = toneRecord["ratingTotal"] as? Int ?? 0
        if let previousStars {
            toneRecord["ratingTotal"] = (total - previousStars + clamped) as CKRecordValue
        } else {
            toneRecord["ratingCount"] = (count + 1) as CKRecordValue
            toneRecord["ratingTotal"] = (total + clamped) as CKRecordValue
        }
        _ = try await database.save(toneRecord)
    }

    static func myRating(toneID: String, userID: String) async -> Int? {
        let ratingID = CKRecord.ID(recordName: "rating|\(toneID)|\(userID)")
        guard let record = try? await database.record(for: ratingID) else {
            return nil
        }
        return record["stars"] as? Int
    }

    // MARK: - Helpers

    private static func pedalsJSON(_ pedals: [EffectPedal]) -> String {
        guard let data = try? JSONEncoder().encode(pedals),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

extension CommunityTone {
    /// Rebuilds a catalog song from the tone's stored metadata so browse
    /// rows can deep-link into the song page without an iTunes round trip.
    var asCatalogSong: CatalogSong {
        CatalogSong(
            trackId: trackID,
            trackName: songTitle,
            artistName: artistName,
            collectionName: albumName.isEmpty ? nil : albumName,
            releaseDate: year > 0 ? "\(year)-01-01" : nil,
            primaryGenreName: genre.rawValue,
            artworkUrl100: artworkURL?.absoluteString
        )
    }
}

/// One song in the community browse feed — all its tones rolled up.
struct CommunitySongSummary: Identifiable, Hashable {
    let song: CatalogSong
    let toneCount: Int
    let bestAverage: Double?
    let ratingCount: Int
    let latest: Date
    let characters: Set<ToneCharacter>

    var id: Int { song.trackId }
}

extension Array where Element == CommunityTone {
    /// Groups a flat tone feed into per-song summaries.
    func groupedBySong() -> [CommunitySongSummary] {
        var groups: [Int: [CommunityTone]] = [:]
        for tone in self {
            groups[tone.trackID, default: []].append(tone)
        }
        return groups.values.compactMap { tones in
            guard let first = tones.first else { return nil }
            return CommunitySongSummary(
                song: first.asCatalogSong,
                toneCount: tones.count,
                bestAverage: tones.compactMap { $0.averageRating }.max(),
                ratingCount: tones.reduce(0) { $0 + $1.ratingCount },
                latest: tones.map { $0.createdAt }.max() ?? first.createdAt,
                characters: Set(tones.map { $0.character })
            )
        }
    }
}

extension CommunityTone {
    init?(record: CKRecord) {
        guard let trackID = record["trackID"] as? Int,
              let songTitle = record["songTitle"] as? String,
              let artistName = record["artistName"] as? String,
              let toneName = record["toneName"] as? String else {
            return nil
        }

        var pedals: [EffectPedal] = []
        if let json = record["pedalsJSON"] as? String,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([EffectPedal].self, from: data) {
            pedals = decoded
        }

        let artworkString = record["artworkURLString"] as? String ?? ""

        self.init(
            id: record.recordID.recordName,
            trackID: trackID,
            songTitle: songTitle,
            artistName: artistName,
            albumName: record["albumName"] as? String ?? "",
            year: record["year"] as? Int ?? 0,
            genre: Genre(rawValue: record["genre"] as? String ?? "") ?? .rock,
            artworkURL: artworkString.isEmpty ? nil : URL(string: artworkString),
            toneName: toneName,
            character: ToneCharacter(rawValue: record["character"] as? String ?? "") ?? .crunch,
            ampName: record["ampName"] as? String ?? "",
            settings: AmpSettings(
                gain: record["gain"] as? Double ?? 5,
                bass: record["bass"] as? Double ?? 5,
                mid: record["mid"] as? Double ?? 5,
                treble: record["treble"] as? Double ?? 5,
                presence: record["presence"] as? Double,
                reverb: record["reverb"] as? Double
            ),
            guitar: record["guitar"] as? String ?? "",
            pickup: record["pickup"] as? String ?? "",
            pedals: pedals,
            notes: record["notes"] as? String ?? "",
            authorName: record["authorName"] as? String ?? "Guitarist",
            ratingCount: record["ratingCount"] as? Int ?? 0,
            ratingTotal: record["ratingTotal"] as? Int ?? 0,
            createdAt: record.creationDate ?? Date()
        )
    }
}
