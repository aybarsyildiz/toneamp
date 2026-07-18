import SwiftUI

/// Pro feature: "Identify Tones" — asks the AI tone engine for the song's
/// tones behind a magical full-screen loading experience.
struct AIToneFinderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @Environment(RigStore.self) private var rigStore
    @Environment(AIToneCacheStore.self) private var aiCache
    let song: CatalogSong
    var onPublished: () -> Void

    private enum Phase {
        case loading
        case failed(String)
        case result([AIGeneratedTone])
    }

    @State private var phase: Phase = .loading
    @State private var publishedToneIDs: Set<UUID> = []
    @State private var publishingToneID: UUID?
    @State private var showingSignIn = false
    @State private var publishError: String?

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    MagicalLoadingView(song: song)
                case .failed(let message):
                    ContentUnavailableView {
                        Label("No Magic This Time", systemImage: "wand.and.stars.inverse")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") {
                            phase = .loading
                            Task { await identify() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                case .result(let tones):
                    resultList(tones)
                }
            }
            .navigationTitle("Identify Tones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSignIn) {
                SignInSheet()
            }
        }
        .interactiveDismissDisabled(isLoading)
        .task {
            await identify()
        }
    }

    private var isLoading: Bool {
        if case .loading = phase {
            return true
        }
        return false
    }

    @MainActor
    private func identify() async {
        do {
            let tones = try await AIToneService.identifyTones(for: song, rig: rigStore.rig)
            // Persist immediately — Pro results belong to the user.
            aiCache.save(tones, for: song, rigDescription: rigStore.rig.aiDescription)
            withAnimation(.spring(duration: 0.6)) {
                phase = .result(tones)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func resultList(_ tones: [AIGeneratedTone]) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SongArtworkView(genre: song.genre, artworkURL: song.artworkURL, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.trackName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(song.artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Label("Identified & saved to your AI tones", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }

            ForEach(tones) { tone in
                Section {
                    HStack {
                        Label(tone.ampName, systemImage: "amplifier")
                        Spacer()
                        CharacterBadge(character: tone.character)
                    }
                    AmpPanelView(settings: tone.settings)
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
                    if tone.pedals.isEmpty {
                        Label("Straight into the amp — no pedals", systemImage: "cable.connector")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tone.pedals) { pedal in
                            PedalRow(pedal: pedal)
                        }
                    }
                    if !tone.notes.isEmpty {
                        Text(tone.notes)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    if tone.rigTips.isEmpty {
                        RigTipsView(pickup: tone.pickup, amp: tone.ampName, pedals: tone.pedals)
                    } else {
                        // Tips written by the engine for the user's exact gear.
                        ForEach(tone.rigTips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .foregroundStyle(.tint)
                                    .frame(width: 24)
                                Text(tip)
                                    .font(.callout)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    publishButton(for: tone)
                } header: {
                    Text(tone.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }

            if let publishError {
                Section {
                    Text(publishError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .headerProminence(.increased)
    }

    @ViewBuilder
    private func publishButton(for tone: AIGeneratedTone) -> some View {
        if publishedToneIDs.contains(tone.id) {
            Label("Published to the community", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button {
                publish(tone)
            } label: {
                Group {
                    if publishingToneID == tone.id {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Publishing…")
                        }
                    } else {
                        Label("Publish to Community", systemImage: "paperplane.fill")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(publishingToneID != nil)
        }
    }

    private func publish(_ tone: AIGeneratedTone) {
        guard let userID = session.userID else {
            showingSignIn = true
            return
        }
        publishingToneID = tone.id
        publishError = nil
        let draft = ToneDraft(
            song: song,
            toneName: tone.name,
            character: tone.character,
            ampName: tone.ampName,
            settings: tone.settings,
            guitar: tone.guitar,
            pickup: tone.pickup,
            pedals: tone.pedals,
            notes: tone.notes
        )
        Task { @MainActor in
            do {
                try await CommunityService.publish(
                    draft,
                    authorName: session.authorName,
                    authorID: userID
                )
                publishedToneIDs.insert(tone.id)
                onPublished()
            } catch {
                publishError = error.localizedDescription
            }
            publishingToneID = nil
        }
    }
}

/// The "something magical is happening" screen: breathing gradient orb,
/// orbiting sparkles, shimmering progress bar, and cycling status lines.
struct MagicalLoadingView: View {
    let song: CatalogSong

    @State private var breathe = false
    @State private var orbit = false
    @State private var shimmer = false
    @State private var messageIndex = 0

    private let messages = [
        "Listening to the record…",
        "Reading the liner notes…",
        "Tracing the signal chain…",
        "Chasing the amp settings…",
        "Auditioning pedals…",
        "Dialing in the knobs…",
        "Almost there…",
    ]

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.55), Color.accentColor.opacity(0.05)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 130
                        )
                    )
                    .frame(width: 230, height: 230)
                    .scaleEffect(breathe ? 1.12 : 0.9)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: breathe)

                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.clear, Color.accentColor.opacity(0.9), .clear],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(orbit ? 360 : 0))
                    .animation(.linear(duration: 2.4).repeatForever(autoreverses: false), value: orbit)

                SongArtworkView(genre: song.genre, artworkURL: song.artworkURL, size: 110)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 20)

                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative.reversing)
                    .offset(x: 62, y: -62)
            }

            VStack(spacing: 10) {
                Text("Identifying Tones")
                    .font(.title2.bold())
                Text(messages[messageIndex])
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: messageIndex)
            }

            shimmerBar
                .padding(.horizontal, 60)

            Text("\(song.trackName) · \(song.artistName)")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .onAppear {
            breathe = true
            orbit = true
            shimmer = true
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_200_000_000)
                guard !Task.isCancelled else { break }
                withAnimation {
                    messageIndex = (messageIndex + 1) % messages.count
                }
            }
        }
    }

    private var shimmerBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.tertiarySystemFill))
                LinearGradient(
                    colors: [.clear, Color.accentColor.opacity(0.85), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.45)
                .clipShape(Capsule())
                .offset(x: shimmer ? proxy.size.width : -proxy.size.width * 0.45)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false), value: shimmer)
            }
        }
        .frame(height: 6)
        .accessibilityLabel("Identifying tones")
    }
}
