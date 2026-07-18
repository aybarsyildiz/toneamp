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
}

enum AIToneError: LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case malformedResponse
    case refused
    case truncated
    case noTones

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Anthropic API key in Settings → ToneAmp Pro to identify tones."
        case .httpError(let code, let message):
            return "Tone engine error (\(code)): \(message)"
        case .malformedResponse:
            return "The tone engine returned an unexpected response. Try again."
        case .refused:
            return "The tone engine declined this request."
        case .truncated:
            return "The response was cut short. Try again."
        case .noTones:
            return "The tone engine couldn't find a guitar tone for this song."
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

    static var hasAPIKey: Bool {
        resolvedAPIKey != nil
    }

    static func identifyTones(for song: CatalogSong) async throws -> [AIGeneratedTone] {
        guard let apiKey = resolvedAPIKey else {
            throw AIToneError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody(song: song))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIToneError.malformedResponse
        }
        guard http.statusCode == 200 else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw AIToneError.httpError(http.statusCode, envelope?.error.message ?? "Unknown error")
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
            throw AIToneError.malformedResponse
        }

        let payload = try JSONDecoder().decode(GeneratedPayload.self, from: jsonData)
        guard payload.found, !payload.tones.isEmpty else {
            throw AIToneError.noTones
        }
        return payload.tones.map { $0.toGeneratedTone() }
    }

    // MARK: - Request

    private static func requestBody(song: CatalogSong) throws -> [String: Any] {
        let schemaData = Data(schemaJSON.utf8)
        let schema = try JSONSerialization.jsonObject(with: schemaData)
        let genreName = song.primaryGenreName ?? "Rock"
        let yearText = song.year > 0 ? String(song.year) : "unknown year"
        return [
            "model": modelID,
            "max_tokens": 8000,
            "thinking": ["type": "adaptive"],
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": "Identify the guitar tones for \u{201C}\(song.trackName)\u{201D} by \(song.artistName) (\(yearText), \(genreName)).",
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
    - If the song has no meaningful guitar part or you don't know it, set found to false \
    with empty tones.
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
            "required": ["name", "character", "amp", "settings", "guitar", "pickup", "pedals", "notes"],
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
              "notes": {"type": "string"}
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
                    notes: notes
                )
            }
        }

        let found: Bool
        let tones: [GTone]
    }
}
