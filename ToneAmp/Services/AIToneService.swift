import Foundation

/// A tone proposed by the AI for a specific catalog song.
struct AIGeneratedTone: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let character: ToneCharacter
    let ampName: String
    let settings: AmpSettings
    let guitar: String
    let pickup: String
    let pedals: [EffectPedal]
    let notes: String
    /// Tips written for the player's specific rig (empty if no rig set).
    let rigTips: [String]
}

/// Everything needed to adapt an existing tone to the player's rig —
/// constructible from library, community, or saved-AI tones.
struct ToneAdaptationInput {
    let trackID: Int
    let songTitle: String
    let artist: String
    let albumName: String
    let year: Int
    let genre: Genre
    let artworkURL: URL?
    let toneName: String
    let ampName: String
    let settings: AmpSettings
    let guitar: String
    let pickup: String
    let pedals: [EffectPedal]
    let notes: String

    var asCatalogSong: CatalogSong {
        CatalogSong(
            trackId: trackID,
            trackName: songTitle,
            artistName: artist,
            collectionName: albumName.isEmpty ? nil : albumName,
            releaseDate: year > 0 ? "\(year)-01-01" : nil,
            primaryGenreName: genre.rawValue,
            artworkUrl100: artworkURL?.absoluteString
        )
    }

    /// Stable pseudo-ID for library songs that have no iTunes track ID.
    static func syntheticTrackID(for songID: String) -> Int {
        var hash: UInt64 = 5381
        for byte in songID.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return -Int(hash % 9_000_000)
    }
}

enum AIToneError: LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case malformedResponse(String)
    case degenerate(String)
    case refused
    case truncated
    case noTones
    case network(String)
    case rateLimited(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Anthropic API key in Settings → ToneAmp Pro to identify tones."
        case .httpError(let code, let message):
            return "Tone engine error (\(code)): \(message)"
        case .malformedResponse(let detail):
            return "The tone engine returned an unexpected response after 3 attempts.\n\nEngine said: \(detail)"
        case .degenerate(let detail):
            return "The tone engine returned unusable settings after 3 attempts.\n\nEngine said: \(detail)"
        case .refused:
            return "The tone engine declined this request."
        case .truncated:
            return "The response was cut short. Try again."
        case .noTones:
            return "The tone engine couldn't find a guitar tone for this song."
        case .network(let detail):
            return "Couldn't reach the tone engine after 3 attempts.\n\n\(detail)"
        case .rateLimited(let detail):
            return detail
        }
    }
}

/// Pro feature: "Identify Tones". Asks Claude for 1–3 tones for a canonical
/// catalog song. Structured outputs (`output_config.format` with a JSON
/// schema mirroring the app models) make the reply guaranteed-parseable —
/// the prompt engineering lives in the schema plus a tight system prompt.
enum AIToneService {
    static let modelID = "claude-opus-4-8"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        return URLSession(configuration: config)
    }()

    /// Key resolution: the Keychain (user-entered) wins; otherwise a
    /// `Secrets.plist` bundled in dev builds. Secrets.plist is gitignored —
    /// never commit or App-Store-ship an embedded key; production goes
    /// through a backend proxy.
    static var resolvedAPIKey: String? {
        if let key = KeychainStore.read(forKey: KeychainStore.anthropicAPIKeyAccount),
           !key.isEmpty {
            return key
        }
        return bundledAPIKey
    }

    static var bundledAPIKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let key = dict["AnthropicAPIKey"] as? String,
              !key.isEmpty else {
            return nil
        }
        return key
    }

    /// Optional production proxy: when `Secrets.plist` carries a
    /// `ToneProxyURL`, requests go there with no client-side key — the
    /// proxy (server/toneamp-proxy) injects it. This is the App Store path.
    static var proxyURL: URL? {
        guard let string = secretsValue("ToneProxyURL"),
              let url = URL(string: string) else {
            return nil
        }
        return url
    }

    private static func secretsValue(_ key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let value = dict[key] as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    static var hasAPIKey: Bool {
        proxyURL != nil || resolvedAPIKey != nil
    }

    private static func makeRequest() throws -> URLRequest {
        var request = URLRequest(url: proxyURL ?? endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if proxyURL != nil {
            if let token = secretsValue("ToneProxyToken") {
                request.setValue(token, forHTTPHeaderField: "x-toneamp-token")
            }
            // Stable identity for the proxy's per-user rate limiting.
            let userID = KeychainStore.read(forKey: KeychainStore.appleUserIDAccount) ?? "anonymous"
            request.setValue(userID, forHTTPHeaderField: "x-toneamp-user")
        } else {
            guard let apiKey = resolvedAPIKey else {
                throw AIToneError.missingAPIKey
            }
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        return request
    }

    static func identifyTones(for song: CatalogSong, rig: UserRig? = nil) async throws -> [AIGeneratedTone] {
        var request = try makeRequest()
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(song: song, rig: rig))

        // Validate + retry: a degenerate (all-zero), malformed, or dropped
        // response is silently re-requested (3 attempts) instead of ever
        // reaching the screen; the final failure carries what the engine
        // actually returned so the error state is diagnosable.
        var lastError: Error = AIToneError.malformedResponse("No response received.")
        for _ in 0..<3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AIToneError.malformedResponse("Non-HTTP response.")
                }
                guard http.statusCode == 200 else {
                    let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
                    let detail = envelope?.error.message ?? String(decoding: data.prefix(300), as: UTF8.self)
                    if http.statusCode == 429 {
                        throw AIToneError.rateLimited(detail)
                    }
                    throw AIToneError.httpError(http.statusCode, detail)
                }

                let message = try JSONDecoder().decode(APIResponse.self, from: data)
                if message.stopReason == "refusal" {
                    throw AIToneError.refused
                }
                if message.stopReason == "max_tokens" {
                    throw AIToneError.truncated
                }
                guard let text = message.content.first(where: { $0.type == "text" })?.text,
                      let jsonData = text.data(using: .utf8) else {
                    throw AIToneError.malformedResponse("Empty response (stop reason: \(message.stopReason ?? "none")).")
                }

                guard let payload = try? JSONDecoder().decode(GeneratedPayload.self, from: jsonData) else {
                    throw AIToneError.malformedResponse(String(text.prefix(400)))
                }
                guard payload.found, !payload.tones.isEmpty else {
                    throw AIToneError.noTones
                }
                let valid = payload.tones.map { $0.toGeneratedTone() }.filter { !isDegenerate($0) }
                if valid.isEmpty {
                    lastError = AIToneError.degenerate(String(text.prefix(400)))
                    continue
                }
                return valid
            } catch let error as AIToneError {
                switch error {
                case .httpError, .refused, .missingAPIKey, .noTones, .truncated, .rateLimited:
                    throw error
                default:
                    lastError = error
                }
            } catch {
                lastError = AIToneError.network(error.localizedDescription)
            }
        }
        throw lastError
    }

    /// Pro: translate a specific existing tone onto the player's rig.
    /// Returns exactly one adapted tone (same schema as identifyTones).
    static func adaptTone(_ input: ToneAdaptationInput, rig: UserRig) async throws -> AIGeneratedTone {
        var request = try makeRequest()

        let schemaData = Data(schemaJSON.utf8)
        let schema = try JSONSerialization.jsonObject(with: schemaData)
        let pedalText = input.pedals.map { pedal in
            let controls = pedal.controls.map { "\($0.name) \($0.value)" }.joined(separator: ", ")
            return "\(pedal.name) (\(pedal.type.rawValue)\(controls.isEmpty ? "" : ": " + controls))"
        }.joined(separator: "; ")
        let content = """
        Adapt this exact tone to the player's own rig.

        Song: \(input.songTitle) by \(input.artist)
        Original tone \u{201C}\(input.toneName)\u{201D}: amp \(input.ampName); \
        gain \(input.settings.gain), bass \(input.settings.bass), mid \(input.settings.mid), \
        treble \(input.settings.treble), presence \(input.settings.presence ?? 0), reverb \(input.settings.reverb ?? 0); \
        guitar \(input.guitar) (\(input.pickup)); \
        pedals: \(pedalText.isEmpty ? "none" : pedalText). Notes: \(input.notes)

        The player's rig — \(rig.aiDescription).

        Return exactly ONE tone in the tones array, translated onto the player's gear:
        - amp = the player's own amp with the channel/model to use (e.g. "Boss GT-8 — 'BG Lead' preamp")
        - settings = the values to dial ON THE PLAYER'S amp/unit to match the original sound — realistic playable values on the 0–10 scale, NEVER all zeros
        - pedals = only gear the player owns; on a multi-FX, express each effect as its own entry named after the unit's block (e.g. "GT-8: OD-1 block", "GT-8: Digital Delay block") with control values
        - guitar/pickup = the best choice from the player's guitars
        - rigTips = ALWAYS 2–4 step-by-step dial-in instructions naming their gear
        - name = "\(input.toneName) — My Gear"

        Sparse-rig rules (follow strictly):
        - If the player lists NO amp (plays direct into an interface/PC): their multi-FX or modeler IS the amp. Pick one of its amp models by name in the amp field and put that amp block's values in settings. Add a rigTip about setting output mode to "Line/Phones" for direct monitoring.
        - If the player lists NO guitar: recommend the original tone's guitar type in the guitar/pickup fields as a suggestion (e.g. "Any humbucker guitar — the record used a Gibson SG") — never empty strings.
        - If the original tone used effects, pedals must not be empty — map every needed effect onto the player's unit or owned pedals.
        """

        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": modelID,
            "max_tokens": 8000,
            "thinking": ["type": "adaptive"],
            "system": systemPrompt,
            "messages": [["role": "user", "content": content]],
            "output_config": ["format": ["type": "json_schema", "schema": schema]],
        ] as [String: Any])

        // Retry loop: sparse rigs occasionally produce a degenerate
        // (all-zero / empty) attempt — 3 tries, and the final failure
        // carries what the engine actually returned.
        var lastError: Error = AIToneError.malformedResponse("No response received.")
        for _ in 0..<3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AIToneError.malformedResponse("Non-HTTP response.")
                }
                guard http.statusCode == 200 else {
                    let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
                    let detail = envelope?.error.message ?? String(decoding: data.prefix(300), as: UTF8.self)
                    if http.statusCode == 429 {
                        throw AIToneError.rateLimited(detail)
                    }
                    throw AIToneError.httpError(http.statusCode, detail)
                }
                let message = try JSONDecoder().decode(APIResponse.self, from: data)
                if message.stopReason == "refusal" {
                    throw AIToneError.refused
                }
                guard let text = message.content.first(where: { $0.type == "text" })?.text,
                      let jsonData = text.data(using: .utf8) else {
                    throw AIToneError.malformedResponse("Empty response (stop reason: \(message.stopReason ?? "none")).")
                }
                guard let payload = try? JSONDecoder().decode(GeneratedPayload.self, from: jsonData),
                      payload.found,
                      let generated = payload.tones.first else {
                    throw AIToneError.malformedResponse(String(text.prefix(400)))
                }
                let tone = generated.toGeneratedTone()
                if isDegenerate(tone) {
                    lastError = AIToneError.degenerate(String(text.prefix(400)))
                    continue
                }
                return tone
            } catch let error as AIToneError {
                switch error {
                case .httpError, .refused, .missingAPIKey, .rateLimited:
                    throw error
                default:
                    lastError = error
                }
            } catch {
                lastError = AIToneError.network(error.localizedDescription)
            }
        }
        throw lastError
    }

    /// A usable adaptation must have real knob values and a named amp.
    private static func isDegenerate(_ tone: AIGeneratedTone) -> Bool {
        let s = tone.settings
        let allZero = s.gain == 0 && s.bass == 0 && s.mid == 0 && s.treble == 0
        let noAmp = tone.ampName.trimmingCharacters(in: .whitespaces).isEmpty
        return allZero || noAmp
    }

    // MARK: - Request

    private static func requestBody(song: CatalogSong, rig: UserRig?) throws -> [String: Any] {
        let schemaData = Data(schemaJSON.utf8)
        let schema = try JSONSerialization.jsonObject(with: schemaData)
        let genreName = song.primaryGenreName ?? "Rock"
        let yearText = song.year > 0 ? String(song.year) : "unknown year"
        var content = "Identify the guitar tones for \u{201C}\(song.trackName)\u{201D} by \(song.artistName) (\(yearText), \(genreName))."
        if let rig, rig.isConfigured {
            content += "\n\nThe player's own rig — \(rig.aiDescription). For each tone, fill rigTips with 1–3 short, concrete tips translating the recording's settings onto this exact rig, naming their gear. If they use a multi-FX or modeler, name the exact block/model inside their unit for each effect (e.g. \u{201C}on the HeadRush, use the Tube Drive block for the TS9\u{201D}). IMPORTANT: the rig affects ONLY rigTips — the amp, settings, guitar, pickup, and pedals fields must describe the gear heard on the ORIGINAL RECORDING, never the player's own gear."
        } else {
            content += "\n\nNo rig information — leave rigTips as an empty array."
        }
        return [
            "model": modelID,
            "max_tokens": 8000,
            "thinking": ["type": "adaptive"],
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": content,
                ]
            ],
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": schema,
                ]
            ],
        ]
    }

    private static let systemPrompt = """
    You are the tone engine for ToneAmp, an iOS app for guitarists. Given a specific \
    recording, produce its guitar tone recipe(s).

    Ground your answer in widely reported information: artist interviews, rig rundowns, \
    isolated tracks, and community consensus. Where exact settings are unknown, give a \
    credible starting point.

    Rules:
    - 1 to 3 tones, one per distinct guitar sound in the song (e.g. clean verse, distorted \
    chorus, solo), in song order.
    - Every knob value uses a 0–10 scale with at most one decimal. For presence and reverb \
    use 0 if the amp has none.
    - Include every pedal that meaningfully shapes the recorded tone, in signal-chain \
    order, each with realistic control values on the same scale. If a pedal has no \
    relevant knobs (e.g. a wah), use an empty controls array and explain usage in its note.
    - Name real amps, guitars, and pedals used on the recording where known.
    - Keep notes practical and concise: tuning, technique, what makes the tone work.
    - Set found to false ONLY when the music genuinely has no guitar at all (solo piano, \
    a cappella, pure electronic). NEVER because you don't know the specific song: if the \
    exact recording is unfamiliar, infer a credible tone from the artist's overall sound, \
    genre, era, and scene — and open the notes with "Based on \
    the artist's typical sound" so the player knows it's inferred.
    - Knob values must always be realistic, playable settings. A tone whose gain, bass, \
    mid, and treble are all 0 is INVALID — never return one. Amp, guitar, and pickup \
    fields must never be empty strings.
    - Pedal names must be specific commercial products — brand + model, e.g. \
    "Ibanez TS9 Tube Screamer", "Boss DD-3 Digital Delay", "MXR Carbon Copy". NEVER a \
    bare effect type like "Overdrive", "Delay", or "Noise Gate": players on modelers \
    (HeadRush, Helix, GT-series) need an exact model to pick the right block.
    - When a player's rig is mentioned, it exists ONLY to write rigTips. Unless the \
    task is explicitly to adapt a tone onto the player's rig, the amp, settings, \
    guitar, pickup, and pedals fields always describe the ORIGINAL RECORDING.
    """

    private static let schemaJSON = """
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["found", "tones"],
      "properties": {
        "found": {"type": "boolean"},
        "tones": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["name", "character", "amp", "settings", "guitar", "pickup", "pedals", "notes", "rigTips"],
            "properties": {
              "name": {"type": "string"},
              "character": {"type": "string", "enum": ["Clean", "Crunch", "Overdrive", "High Gain", "Fuzz", "Lead"]},
              "amp": {"type": "string"},
              "settings": {
                "type": "object",
                "additionalProperties": false,
                "required": ["gain", "bass", "mid", "treble", "presence", "reverb"],
                "properties": {
                  "gain": {"type": "number"},
                  "bass": {"type": "number"},
                  "mid": {"type": "number"},
                  "treble": {"type": "number"},
                  "presence": {"type": "number"},
                  "reverb": {"type": "number"}
                }
              },
              "guitar": {"type": "string"},
              "pickup": {"type": "string"},
              "pedals": {
                "type": "array",
                "items": {
                  "type": "object",
                  "additionalProperties": false,
                  "required": ["name", "type", "controls", "note"],
                  "properties": {
                    "name": {"type": "string"},
                    "type": {"type": "string", "enum": ["overdrive", "distortion", "fuzz", "boost", "delay", "reverb", "chorus", "phaser", "flanger", "wah", "compressor", "octave", "eq"]},
                    "controls": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "additionalProperties": false,
                        "required": ["name", "value"],
                        "properties": {
                          "name": {"type": "string"},
                          "value": {"type": "number"}
                        }
                      }
                    },
                    "note": {"type": "string"}
                  }
                }
              },
              "notes": {"type": "string"},
              "rigTips": {"type": "array", "items": {"type": "string"}}
            }
          }
        }
      }
    }
    """

    // MARK: - Response envelopes

    private struct APIResponse: Decodable {
        struct Block: Decodable {
            let type: String
            let text: String?
        }

        let content: [Block]
        let stopReason: String?

        enum CodingKeys: String, CodingKey {
            case content
            case stopReason = "stop_reason"
        }
    }

    private struct APIErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let message: String
        }

        let error: APIError
    }

    private struct GeneratedPayload: Decodable {
        struct GTone: Decodable {
            struct GSettings: Decodable {
                let gain: Double
                let bass: Double
                let mid: Double
                let treble: Double
                let presence: Double
                let reverb: Double
            }

            struct GPedal: Decodable {
                struct GControl: Decodable {
                    let name: String
                    let value: Double
                }

                let name: String
                let type: String
                let controls: [GControl]
                let note: String
            }

            let name: String
            let character: String
            let amp: String
            let settings: GSettings
            let guitar: String
            let pickup: String
            let pedals: [GPedal]
            let notes: String
            let rigTips: [String]?

            func toGeneratedTone() -> AIGeneratedTone {
                AIGeneratedTone(
                    name: name,
                    character: ToneCharacter(rawValue: character) ?? .crunch,
                    ampName: amp,
                    settings: AmpSettings(
                        gain: settings.gain,
                        bass: settings.bass,
                        mid: settings.mid,
                        treble: settings.treble,
                        presence: settings.presence,
                        reverb: settings.reverb
                    ),
                    guitar: guitar,
                    pickup: pickup,
                    pedals: pedals.map { pedal in
                        EffectPedal(
                            name: pedal.name,
                            type: EffectType(rawValue: pedal.type) ?? .overdrive,
                            controls: pedal.controls.map {
                                PedalControl(name: $0.name, value: $0.value)
                            },
                            note: pedal.note
                        )
                    },
                    notes: notes,
                    rigTips: rigTips ?? []
                )
            }
        }

        let found: Bool
        let tones: [GTone]
    }
}
