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
        } else {
            parts.append("Amp: none — plays direct into an audio interface/PC or headphones")
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

/// A concrete, searchable piece of gear the player can add to their rig.
struct GearItem: Identifiable, Hashable {
    enum Category: String, CaseIterable {
        case guitar = "Guitars"
        case amp = "Amps"
        case multiFX = "Multi-FX & Modelers"
        case pedal = "Pedals"

        var symbol: String {
            switch self {
            case .guitar: return "guitars.fill"
            case .amp: return "amplifier"
            case .multiFX: return "square.grid.3x3.fill"
            case .pedal: return "bolt.fill"
            }
        }
    }

    let name: String
    let category: Category

    var id: String { name }
}

extension GearCatalog {
    /// Popular gear, searchable in onboarding and the rig editor.
    static let popularGear: [GearItem] = {
        let guitars = [
            "Fender Stratocaster", "Fender Player Stratocaster", "Fender American Pro Stratocaster",
            "Fender Telecaster", "Fender Player Telecaster", "Fender Vintera Stratocaster",
            "Fender Jazzmaster", "Fender Jaguar", "Fender Mustang", "Fender Duo-Sonic",
            "Squier Stratocaster", "Squier Classic Vibe Stratocaster", "Squier Telecaster",
            "Squier Classic Vibe Telecaster", "Squier Jazzmaster",
            "Gibson Les Paul Standard", "Gibson Les Paul Studio", "Gibson Les Paul Classic",
            "Gibson Les Paul Special", "Gibson SG Standard", "Gibson SG Special",
            "Gibson ES-335", "Gibson ES-339", "Gibson Explorer", "Gibson Flying V", "Gibson Firebird",
            "Epiphone Les Paul", "Epiphone SG", "Epiphone Casino", "Epiphone Dot",
            "Epiphone Explorer", "Epiphone Flying V",
            "PRS Custom 24", "PRS SE Custom 24", "PRS S2 Vela", "PRS McCarty 594", "PRS Silver Sky",
            "Ibanez RG550", "Ibanez RG421", "Ibanez RG5xx Prestige", "Ibanez AZ", "Ibanez AZES",
            "Ibanez S Series", "Ibanez JEM", "Ibanez Gio",
            "Jackson Soloist", "Jackson Dinky", "Jackson Rhoads", "Jackson Kelly",
            "ESP LTD EC-1000", "ESP LTD M-1000", "ESP Eclipse", "ESP Horizon", "ESP LTD KH-602",
            "Schecter Hellraiser", "Schecter C-1", "Schecter Omen", "Dean ML",
            "Charvel Pro-Mod DK24", "Music Man JP6", "Music Man Cutlass", "Sterling by Music Man",
            "Suhr Classic S", "Yamaha Pacifica 112", "Yamaha Pacifica 612", "Yamaha Revstar",
            "Gretsch Streamliner", "Gretsch Duo Jet", "Gretsch White Falcon",
            "Rickenbacker 330", "Danelectro '59", "Reverend Charger", "Chapman ML1",
            "Solar A-Type", "Harley Benton TE-52", "Harley Benton SC-450", "Harley Benton Fusion",
            "Cort G250", "Cort KX Series",
        ].map { GearItem(name: $0, category: .guitar) }
        let amps = [
            "Boss Katana 50", "Boss Katana 100", "Fender Mustang GTX", "Fender Blues Junior",
            "Fender Deluxe Reverb", "Fender Twin Reverb", "Fender Champion 40",
            "Marshall DSL40CR", "Marshall JCM800", "Marshall Code 50", "Marshall MG30",
            "Marshall Origin 20", "Vox AC15", "Vox AC30", "Vox Valvetronix VT40X",
            "Orange Crush 35RT", "Orange Rockerverb", "Mesa/Boogie Dual Rectifier",
            "Mesa/Boogie Mark V", "Peavey 6505", "EVH 5150 Iconic", "Positive Grid Spark 40",
            "Line 6 Catalyst 60", "Blackstar HT Club 40", "Blackstar ID:Core 40",
            "Roland JC-120", "Roland Cube", "Laney Cub", "Hughes & Kettner TubeMeister",
            "Supro Delta King", "Bugera V22", "Fender Hot Rod Deluxe", "Fender Princeton Reverb",
            "Fender Tone Master Deluxe", "Marshall Silver Jubilee", "Marshall Studio Classic SC20",
            "Vox MV50", "Orange Micro Terror", "PRS Archon", "Soldano SLO-30", "Friedman BE-100",
            "Boss Nextone", "Boss Katana Artist", "Yamaha THR10 II", "Yamaha THR30 II",
            "Positive Grid Spark Mini", "Blackstar Debut 50R",
            "Audio interface (direct to PC)", "FRFR cab / powered speaker", "Headphones (direct)",
        ].map { GearItem(name: $0, category: .amp) }
        let multiFX = [
            "Boss GT-8", "Boss GT-100", "Boss GT-1000", "Boss GX-100", "Boss ME-80",
            "Boss GT-1", "Line 6 Helix", "Line 6 HX Stomp", "Line 6 POD Go", "Line 6 POD HD500X",
            "Fractal Axe-FX III", "Neural DSP Quad Cortex", "Headrush MX5", "Headrush Pedalboard",
            "Zoom G5n", "Zoom G1X Four", "Zoom G3Xn", "Zoom G11", "Zoom MS-50G+",
            "Mooer GE200", "Mooer GE250", "Mooer GE300", "NUX MG-30", "NUX MG-400",
            "Valeton GP-200", "Hotone Ampero II", "Hotone Ampero Mini", "TC Electronic Plethora X5",
            "Line 6 HX Effects", "Fractal FM3", "Fractal FM9", "Kemper Profiler",
            "Kemper Profiler Player", "Neural DSP Nano Cortex", "Strymon Iridium",
            "UAFX Dream '65", "UAFX Ruby '63", "Eventide H9", "Boss GX-10", "IK ToneX Pedal",
        ].map { GearItem(name: $0, category: .multiFX) }
        let pedals = [
            "Ibanez Tube Screamer TS9", "Ibanez Tube Screamer TS808", "Boss SD-1", "Boss BD-2",
            "Boss DS-1", "Boss MT-2 Metal Zone", "ProCo RAT 2", "EHX Big Muff Pi",
            "Dunlop Fuzz Face", "EHX Soul Food", "Klon KTR", "Wampler Tumnus", "EarthQuaker Plumes",
            "JHS Morning Glory", "Fulltone OCD", "Boss DD-8", "Boss DD-3T", "MXR Carbon Copy",
            "EHX Memory Man", "Boss RE-2 Space Echo", "TC Flashback 2", "Boss RV-6",
            "TC Hall of Fame 2", "EHX Holy Grail", "Boss CE-2W", "Boss CH-1", "EHX Small Clone",
            "MXR Phase 90", "MXR Phase 95", "EHX Electric Mistress", "Dunlop Cry Baby",
            "Vox V847 Wah", "MXR Dyna Comp", "Keeley Compressor Plus", "Boss GE-7 EQ",
            "DigiTech Whammy", "EHX POG2", "Boss OC-5", "Boss OD-3", "Boss HM-2W", "Boss BF-3",
            "Boss PH-3", "Boss TR-2", "Boss NS-2 Noise Suppressor", "Boss DD-200", "Boss DD-500",
            "Strymon Timeline", "Strymon BigSky", "Strymon El Capistan", "Strymon Flint",
            "EarthQuaker Dispatch Master", "EarthQuaker Avalanche Run", "EarthQuaker Hoof",
            "Walrus Julia", "Walrus Slö", "Walrus ARP-87", "JHS 3 Series Overdrive",
            "Wampler Ego Compressor", "Xotic SL Drive", "Xotic EP Booster", "MXR Distortion+",
            "MXR Micro Amp", "MXR 10-Band EQ", "EHX Canyon", "EHX Oceans 11", "EHX Nano Big Muff",
            "Ibanez TS Mini", "Dunlop 535Q Wah", "Morley Bad Horsie", "DigiTech Drop",
            "TC Ditto Looper", "Boss RC-1 Loop Station",
        ].map { GearItem(name: $0, category: .pedal) }
        return guitars + amps + multiFX + pedals
    }()
}

extension RigStore {
    /// Concrete gear items live in the free-text fields as comma lists —
    /// the advisor's keyword inference and the AI both read them.
    func isSelected(_ item: GearItem) -> Bool {
        switch item.category {
        case .guitar:
            return rig.guitarText.localizedCaseInsensitiveContains(item.name)
        case .amp:
            return rig.ampText.localizedCaseInsensitiveContains(item.name)
        case .multiFX, .pedal:
            return rig.pedalsText.localizedCaseInsensitiveContains(item.name)
        }
    }

    func toggle(_ item: GearItem) {
        switch item.category {
        case .guitar:
            rig.guitarText = Self.toggling(item.name, in: rig.guitarText)
        case .amp:
            rig.ampText = Self.toggling(item.name, in: rig.ampText)
        case .multiFX:
            rig.pedalsText = Self.toggling(item.name, in: rig.pedalsText)
            if isSelected(item) {
                if !rig.pedalTypes.contains(GearCatalog.multiFXKey) {
                    rig.pedalTypes.append(GearCatalog.multiFXKey)
                }
            } else if !GearCatalog.hasMultiFX(rig) {
                rig.pedalTypes.removeAll { $0 == GearCatalog.multiFXKey }
            }
        case .pedal:
            rig.pedalsText = Self.toggling(item.name, in: rig.pedalsText)
        }
    }

    var selectedGearItems: [GearItem] {
        GearCatalog.popularGear.filter { isSelected($0) }
    }

    private static func toggling(_ name: String, in list: String) -> String {
        var parts = list
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if let index = parts.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            parts.remove(at: index)
        } else {
            parts.append(name)
        }
        return parts.joined(separator: ", ")
    }
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
