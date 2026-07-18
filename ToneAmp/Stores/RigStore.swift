import Foundation
import Observation

/// The player's own gear — the heart of personalization. Chips power the
/// quick local tips; free text describes exact models for the AI engine.
struct UserRig: Codable, Equatable {
    var guitars: [String] = []
    var amp: String = ""
    var pedalTypes: [String] = []
    var guitarText: String = ""
    var ampText: String = ""
    var pedalsText: String = ""

    var isConfigured: Bool {
        !guitars.isEmpty || !amp.isEmpty || !pedalTypes.isEmpty
            || !guitarText.isEmpty || !ampText.isEmpty || !pedalsText.isEmpty
    }

    /// Compact description handed to the AI tone engine.
    var aiDescription: String {
        var parts: [String] = []
        let guitarList = ([guitarText] + guitars).filter { !$0.isEmpty }
        if !guitarList.isEmpty {
            parts.append("Guitars: " + guitarList.joined(separator: ", "))
        }
        let ampList = ([ampText] + [amp]).filter { !$0.isEmpty }
        if !ampList.isEmpty {
            parts.append("Amp: " + ampList.joined(separator: " — "))
        }
        var pedalParts: [String] = []
        if !pedalsText.isEmpty {
            pedalParts.append(pedalsText)
        }
        let categories = pedalTypes.filter { $0 != GearCatalog.multiFXKey }
        if pedalTypes.contains(GearCatalog.multiFXKey) {
            pedalParts.append("owns a multi-FX unit that covers all effect types")
        }
        if !categories.isEmpty {
            pedalParts.append("categories owned: " + categories.joined(separator: ", "))
        }
        if !pedalParts.isEmpty {
            parts.append("Pedals: " + pedalParts.joined(separator: "; "))
        }
        return parts.joined(separator: ". ")
    }

    enum CodingKeys: String, CodingKey {
        case guitars, amp, pedalTypes, guitarText, ampText, pedalsText
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guitars = try container.decodeIfPresent([String].self, forKey: .guitars) ?? []
        amp = try container.decodeIfPresent(String.self, forKey: .amp) ?? ""
        pedalTypes = try container.decodeIfPresent([String].self, forKey: .pedalTypes) ?? []
        guitarText = try container.decodeIfPresent(String.self, forKey: .guitarText) ?? ""
        ampText = try container.decodeIfPresent(String.self, forKey: .ampText) ?? ""
        pedalsText = try container.decodeIfPresent(String.self, forKey: .pedalsText) ?? ""
    }
}

enum GearCatalog {
    static let guitars = [
        "Stratocaster", "Telecaster", "Les Paul", "SG", "Semi-hollow (335)",
        "Jazzmaster / Jaguar", "Superstrat (Ibanez/Jackson)", "Active pickups (EMG)",
        "Acoustic", "Other",
    ]

    static let amps = [
        "Fender-style (clean/scooped)", "Marshall-style (mid-forward)",
        "Vox-style (chimey)", "Mesa/high-gain", "Orange-style (thick)",
        "Modeler (Katana, Helix, …)", "No amp yet",
    ]

    /// Pedal categories a player can own, mirroring `EffectType`.
    static let pedalOptions: [EffectType] = [
        .overdrive, .distortion, .fuzz, .boost, .delay, .reverb,
        .chorus, .phaser, .flanger, .wah, .compressor, .octave, .eq,
    ]

    /// Special rig entry: a multi-FX floorboard/modeler (GT-8, POD, Helix…)
    /// covers every pedal category at once.
    static let multiFXKey = "multifx"
    static let multiFXLabel = "Multi-FX unit (GT, POD, Helix…)"

    static func hasMultiFX(_ rig: UserRig) -> Bool {
        if rig.pedalTypes.contains(multiFXKey) {
            return true
        }
        let text = (rig.pedalsText + " " + rig.ampText).lowercased()
        return ["gt-", "gt8", "gt 8", "gt10", "gt100", "gt1000", "pod", "helix", "hx ", "headrush",
                "multi-fx", "multifx", "multi fx", "fx8", "ax8", "axe-fx", "quad cortex",
                "boss me-", "mooer ge", "nux mg", "valeton", "zoom g"].contains { text.contains($0) }
    }

    static let singleCoilGuitars: Set<String> = [
        "Stratocaster", "Telecaster", "Jazzmaster / Jaguar",
    ]
    static let humbuckerGuitars: Set<String> = [
        "Les Paul", "SG", "Semi-hollow (335)", "Superstrat (Ibanez/Jackson)", "Active pickups (EMG)",
    ]
}

@Observable
final class RigStore {
    private static let defaultsKey = "toneamp.userRig"

    var rig: UserRig {
        didSet {
            persist()
        }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(UserRig.self, from: data) {
            rig = saved
        } else {
            rig = UserRig()
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(rig) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}

/// Translates a tone's rig to the player's rig: small, concrete tips.
enum RigAdvisor {
    static func tips(pickup: String, amp: String, pedals: [EffectPedal], rig: UserRig) -> [String] {
        guard rig.isConfigured else { return [] }
        var tips: [String] = []

        // Pickup translation — chips first, free text as fallback signal
        let toneWantsHumbucker = pickup.localizedCaseInsensitiveContains("humbucker")
        let toneWantsSingle = pickup.localizedCaseInsensitiveContains("single")
        let guitarWords = (rig.guitars.joined(separator: " ") + " " + rig.guitarText).lowercased()
        let hasSingle = !GearCatalog.singleCoilGuitars.isDisjoint(with: rig.guitars)
            || ["strat", "tele", "jazzmaster", "jaguar", "single"].contains { guitarWords.contains($0) }
        let hasHumbucker = !GearCatalog.humbuckerGuitars.isDisjoint(with: rig.guitars)
            || ["les paul", "sg", "335", "humbucker", "ibanez", "jackson", "esp", "emg", "prs", "hss"].contains { guitarWords.contains($0) }
        if toneWantsHumbucker && hasSingle && !hasHumbucker {
            tips.append("This tone uses a humbucker; your single-coils run brighter and quieter — add about half a step of gain and pull treble back slightly.")
        } else if toneWantsSingle && hasHumbucker && !hasSingle {
            tips.append("This tone uses single-coils; your humbuckers run hotter and darker — back the gain off about one step and open up the treble.")
        }

        // Amp family translation — chip first, then the typed amp name
        let toneAmp = ampFamily(of: amp)
        let myAmp = ampFamily(of: rig.amp) ?? ampFamily(of: rig.ampText)
        if let toneAmp, let myAmp, toneAmp != myAmp {
            switch (toneAmp, myAmp) {
            case ("marshall", "fender"):
                tips.append("The record is a mid-forward Marshall; on your Fender-style amp push the mids up ~1 and ease the treble.")
            case ("fender", "marshall"):
                tips.append("The record is a scooped Fender-style clean; on your Marshall pull the mids back ~1 and add a touch of reverb.")
            case (_, "modeler"):
                tips.append("On your modeler, pick the closest \(amp) model — these knob values map over almost directly.")
            case ("mesa", _):
                tips.append("This is a saturated high-gain amp; if your amp runs out of gain, put a drive pedal in front with its level high and gain low.")
            case ("vox", _):
                tips.append("The chime here comes from a Vox-style top end — brighten treble ~1 and reduce bass slightly.")
            default:
                break
            }
        }

        // Pedal coverage — chips plus keywords from the typed pedal list
        var owned = Set(rig.pedalTypes)
        let pedalWords = rig.pedalsText.lowercased()
        let keywordMap: [(String, EffectType)] = [
            ("screamer", .overdrive), ("ts9", .overdrive), ("ts808", .overdrive),
            ("od", .overdrive), ("drive", .overdrive), ("klon", .overdrive), ("blues driver", .overdrive),
            ("ds-", .distortion), ("distortion", .distortion), ("rat", .distortion), ("metal", .distortion),
            ("muff", .fuzz), ("fuzz", .fuzz),
            ("delay", .delay), ("dd-", .delay), ("echo", .delay), ("carbon copy", .delay),
            ("reverb", .reverb), ("hall of fame", .reverb),
            ("chorus", .chorus), ("ce-", .chorus),
            ("phaser", .phaser), ("phase 90", .phaser),
            ("flanger", .flanger),
            ("wah", .wah), ("cry baby", .wah),
            ("comp", .compressor),
            ("whammy", .octave), ("octave", .octave),
            ("eq", .eq),
        ]
        for (keyword, type) in keywordMap where pedalWords.contains(keyword) {
            owned.insert(type.rawValue)
        }
        // A multi-FX unit covers everything — and deserves a patch tip.
        if GearCatalog.hasMultiFX(rig) {
            for type in GearCatalog.pedalOptions {
                owned.insert(type.rawValue)
            }
            if !pedals.isEmpty {
                let chain = pedals.map { $0.name }.joined(separator: " → ")
                tips.append("Build this as one patch on your multi-FX — chain \(chain) in that order with the values shown.")
            }
        }
        let needed = pedals.map { $0.type }
        let missingDirt = needed.first { type in
            (type == .fuzz || type == .overdrive || type == .distortion) && !owned.contains(type.rawValue)
        }
        if let missingDirt {
            let substitute = [EffectType.overdrive, .distortion, .fuzz]
                .first { owned.contains($0.rawValue) && $0 != missingDirt }
            if let substitute {
                tips.append("No \(missingDirt.displayName.lowercased())? Your \(substitute.displayName.lowercased()) can cover it — raise its gain and match the level by ear.")
            } else {
                tips.append("No \(missingDirt.displayName.lowercased()) pedal? Raise the amp gain ~1.5 and cut bass slightly to get close.")
            }
        }
        if needed.contains(.delay) && !owned.contains(EffectType.delay.rawValue) {
            tips.append("No delay? Add about +1 of reverb for a similar sense of space.")
        }
        let covered = needed.filter { owned.contains($0.rawValue) && $0 != .eq }
        if !covered.isEmpty && tips.count < 3 {
            let names = covered.prefix(3).map { $0.displayName.lowercased() }.joined(separator: ", ")
            tips.append("You're covered on \(names) — start from the pedal values shown and trust your ears.")
        }

        return Array(tips.prefix(3))
    }

    private static func ampFamily(of name: String) -> String? {
        let lower = name.lowercased()
        if lower.contains("marshall") || lower.contains("laney") || lower.contains("hiwatt") || lower.contains("plexi") || lower.contains("jcm") { return "marshall" }
        if lower.contains("fender") || lower.contains("twin") || lower.contains("deluxe") || lower.contains("bassman") || lower.contains("vibro") { return "fender" }
        if lower.contains("vox") || lower.contains("ac30") || lower.contains("chimey") { return "vox" }
        if lower.contains("mesa") || lower.contains("rectifier") || lower.contains("5150") || lower.contains("engl") || lower.contains("high-gain") || lower.contains("diezel") || lower.contains("bogner") || lower.contains("randall") || lower.contains("peavey") { return "mesa" }
        if lower.contains("orange") { return "orange" }
        if lower.contains("modeler") || lower.contains("katana") || lower.contains("helix") { return "modeler" }
        return nil
    }
}
