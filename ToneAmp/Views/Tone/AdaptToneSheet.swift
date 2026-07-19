import SwiftUI

/// Pro: "Adapt to My Gear" — takes any existing tone and has the AI engine
/// translate it onto the player's exact rig, with a step-by-step dial-in.
struct AdaptToneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RigStore.self) private var rigStore
    @Environment(AIToneCacheStore.self) private var aiCache
    let input: ToneAdaptationInput

    private enum Phase {
        case loading
        case failed(String)
        case limited(String)
        case result(AIGeneratedTone)
    }

    @State private var phase: Phase = .loading

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    MagicalLoadingView(
                        title: input.songTitle,
                        artist: input.artist,
                        artworkURL: input.artworkURL,
                        genre: input.genre,
                        headline: "Adapting to Your Gear",
                        messages: [
                            "Reading your rig…",
                            "Matching the amp voicing…",
                            "Translating the pedals…",
                            "Choosing your pickup…",
                            "Dialing your knobs…",
                            "Almost there…",
                        ]
                    )
                case .failed(let message):
                    AIFailureView(title: "Couldn't Adapt", message: message) {
                        phase = .loading
                        Task { await adapt() }
                    }
                case .limited(let detail):
                    AILimitReachedView(detail: detail)
                case .result(let tone):
                    resultList(tone)
                }
            }
            .navigationTitle("My Gear Version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(isLoading)
        .task {
            await adapt()
        }
    }

    private var isLoading: Bool {
        if case .loading = phase {
            return true
        }
        return false
    }

    @MainActor
    private func adapt() async {
        do {
            let tone = try await AIToneService.adaptTone(input, rig: rigStore.rig)
            aiCache.save([tone], for: input.asCatalogSong, rigDescription: rigStore.rig.aiDescription)
            withAnimation(.spring(duration: 0.6)) {
                phase = .result(tone)
            }
        } catch {
            if let toneError = error as? AIToneError,
               case .rateLimited(let detail) = toneError {
                phase = .limited(detail)
            } else {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func resultList(_ tone: AIGeneratedTone) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SongArtworkView(genre: input.genre, artworkURL: input.artworkURL, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(input.songTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\u{201C}\(input.toneName)\u{201D} on your gear")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Label("Saved to your AI tones", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Section("Your Amp") {
                HStack {
                    Label(tone.ampName, systemImage: "amplifier")
                    Spacer()
                    CharacterBadge(character: tone.character)
                }
            }

            Section("Dial These In") {
                AmpPanelView(settings: tone.settings)
            }

            Section("Your Guitar") {
                LabeledContent {
                    Text(tone.guitar)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Guitar", systemImage: "guitars.fill")
                }
                LabeledContent {
                    Text(tone.pickup)
                        .multilineTextAlignment(.trailing)
                } label: {
                    Label("Pickup", systemImage: "dot.radiowaves.left.and.right")
                }
            }

            Section("Your Effects") {
                if tone.pedals.isEmpty {
                    Label("Straight into the amp — nothing else needed", systemImage: "cable.connector")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tone.pedals) { pedal in
                        PedalRow(pedal: pedal)
                    }
                }
            }

            if !tone.rigTips.isEmpty {
                Section("Step by Step") {
                    ForEach(Array(tone.rigTips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.accentColor, in: Circle())
                            Text(tip)
                                .font(.callout)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if !tone.notes.isEmpty {
                Section("Notes") {
                    Text(tone.notes)
                        .font(.callout)
                }
            }
        }
    }
}

/// The entry-point button placed on tone detail screens.
struct AdaptToMyGearButton: View {
    @Environment(SessionStore.self) private var session
    @Environment(RigStore.self) private var rigStore
    let input: ToneAdaptationInput

    @State private var showingAdapt = false
    @State private var showingProTeaser = false
    @State private var showingRigEditor = false

    var body: some View {
        Button {
            if !session.isPro {
                showingProTeaser = true
            } else if !rigStore.rig.isConfigured {
                showingRigEditor = true
            } else {
                showingAdapt = true
            }
        } label: {
            Label("Adapt to My Gear", systemImage: "wand.and.rays")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .sheet(isPresented: $showingAdapt) {
            AdaptToneSheet(input: input)
        }
        .fullScreenCover(isPresented: $showingProTeaser) {
            ProPaywallView()
        }
        .sheet(isPresented: $showingRigEditor) {
            MyRigView()
        }
    }
}
