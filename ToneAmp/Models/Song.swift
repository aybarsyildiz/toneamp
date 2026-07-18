import Foundation

struct Song: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let year: Int
    let genre: Genre
    let tones: [Tone]
    let artworkURL: URL?

    init(
        id: String,
        title: String,
        artist: String,
        album: String,
        year: Int,
        genre: Genre,
        tones: [Tone],
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.year = year
        self.genre = genre
        self.tones = tones
        self.artworkURL = artworkURL
    }

    enum CodingKeys: String, CodingKey {
        case id, title, artist, album, year, genre, tones, artworkURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        album = try container.decode(String.self, forKey: .album)
        year = try container.decode(Int.self, forKey: .year)
        genre = try container.decode(Genre.self, forKey: .genre)
        tones = try container.decode([Tone].self, forKey: .tones)
        artworkURL = try container.decodeIfPresent(URL.self, forKey: .artworkURL)
    }

    func withArtwork(_ url: URL) -> Song {
        Song(
            id: id,
            title: title,
            artist: artist,
            album: album,
            year: year,
            genre: genre,
            tones: tones,
            artworkURL: url
        )
    }
}

enum Genre: String, Codable, CaseIterable, Identifiable {
    case rock = "Rock"
    case hardRock = "Hard Rock"
    case metal = "Metal"
    case grunge = "Grunge"
    case bluesRock = "Blues Rock"
    case alternative = "Alternative"
    case funkRock = "Funk Rock"
    case psychedelic = "Psychedelic"
    case anatolian = "Anadolu Rock"

    var id: String { rawValue }
}

struct Tone: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let amp: String
    let character: ToneCharacter
    let settings: AmpSettings
    let guitar: String
    let pickup: String
    let pedals: [EffectPedal]
    let notes: String
}

enum ToneCharacter: String, Codable, CaseIterable {
    case clean = "Clean"
    case crunch = "Crunch"
    case overdrive = "Overdrive"
    case highGain = "High Gain"
    case fuzz = "Fuzz"
    case lead = "Lead"
}

struct AmpSettings: Codable, Hashable {
    let gain: Double
    let bass: Double
    let mid: Double
    let treble: Double
    let presence: Double?
    let reverb: Double?

    init(
        gain: Double,
        bass: Double,
        mid: Double,
        treble: Double,
        presence: Double? = nil,
        reverb: Double? = nil
    ) {
        self.gain = gain
        self.bass = bass
        self.mid = mid
        self.treble = treble
        self.presence = presence
        self.reverb = reverb
    }

    var knobs: [(label: String, value: Double)] {
        var result: [(label: String, value: Double)] = [
            (label: "Gain", value: gain),
            (label: "Bass", value: bass),
            (label: "Mid", value: mid),
            (label: "Treble", value: treble),
        ]
        if let presence {
            result.append((label: "Presence", value: presence))
        }
        if let reverb {
            result.append((label: "Reverb", value: reverb))
        }
        return result
    }
}

struct EffectPedal: Identifiable, Codable, Hashable {
    let name: String
    let type: EffectType
    let controls: [PedalControl]
    let note: String

    var id: String { name }
}

/// One knob on a pedal, on the same 0–10 scale as the amp settings.
struct PedalControl: Identifiable, Codable, Hashable {
    var name: String
    var value: Double

    var id: String { name }
}

enum EffectType: String, Codable, CaseIterable {
    case overdrive
    case distortion
    case fuzz
    case boost
    case delay
    case reverb
    case chorus
    case phaser
    case flanger
    case wah
    case compressor
    case octave
    case eq

    var displayName: String {
        switch self {
        case .overdrive: return "Overdrive"
        case .distortion: return "Distortion"
        case .fuzz: return "Fuzz"
        case .boost: return "Boost"
        case .delay: return "Delay"
        case .reverb: return "Reverb"
        case .chorus: return "Chorus"
        case .phaser: return "Phaser"
        case .flanger: return "Flanger"
        case .wah: return "Wah"
        case .compressor: return "Compressor"
        case .octave: return "Octave"
        case .eq: return "EQ"
        }
    }

    var symbolName: String {
        switch self {
        case .overdrive: return "bolt.fill"
        case .distortion: return "bolt.horizontal.fill"
        case .fuzz: return "flame.fill"
        case .boost: return "arrow.up.circle.fill"
        case .delay: return "clock.arrow.circlepath"
        case .reverb: return "water.waves"
        case .chorus: return "waveform.path"
        case .phaser: return "tornado"
        case .flanger: return "wind"
        case .wah: return "mouth"
        case .compressor: return "rectangle.compress.vertical"
        case .octave: return "arrow.down.to.line"
        case .eq: return "slider.vertical.3"
        }
    }
}
