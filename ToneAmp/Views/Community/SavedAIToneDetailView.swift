import SwiftUI

/// A saved Pro-generated tone: the full sheet plus the rig-specific tips it
/// was generated with, and a path to publish it to the community.
struct SavedAIToneDetailView: View {
    @Environment(SessionStore.self) private var session
    @Environment(AIToneCacheStore.self) private var aiCache
    @Environment(\.dismiss) private var dismiss
    let tone: SavedAITone

    @State private var isPublishing = false
    @State private var isPublished = false
    @State private var publishError: String?
    @State private var showingSignIn = false
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    SongArtworkView(genre: tone.genre, artworkURL: tone.artworkURL, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tone.songTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(tone.artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Label(
                            "Identified \(tone.createdAt.formatted(date: .abbreviated, time: .omitted))",
                            systemImage: "sparkles"
                        )
                        .font(.caption)
                        .foregroundStyle(.tint)
                    }
                }
            }

            Section("Amp") {
                HStack {
                    Label(tone.ampName, systemImage: "amplifier")
                    Spacer()
                    CharacterBadge(character: tone.character)
                }
            }

            Section("Settings") {
                AmpPanelView(settings: tone.settings)
            }

            Section("Guitar") {
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

            Section("Pedals & Effects") {
                if tone.pedals.isEmpty {
                    Label("Straight into the amp — no pedals", systemImage: "cable.connector")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tone.pedals) { pedal in
                        PedalRow(pedal: pedal)
                    }
                }
            }

            if !tone.rigTips.isEmpty {
                Section {
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
                } header: {
                    Text("For Your Rig")
                } footer: {
                    if !tone.rigDescription.isEmpty {
                        Text("Generated for: \(tone.rigDescription)")
                    }
                }
            }

            if !tone.notes.isEmpty {
                Section("Notes") {
                    Text(tone.notes)
                        .font(.callout)
                }
            }

            Section {
                if isPublished {
                    Label("Published to the community", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        publish()
                    } label: {
                        Group {
                            if isPublishing {
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
                    .disabled(isPublishing)
                }
                Button("Delete from My AI Tones", role: .destructive) {
                    confirmingDelete = true
                }
            } footer: {
                if let publishError {
                    Text(publishError)
                }
            }
        }
        .navigationTitle(tone.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: toneShareText(
                        songTitle: tone.songTitle,
                        artist: tone.artistName,
                        toneName: tone.name,
                        amp: tone.ampName,
                        settings: tone.settings,
                        guitar: tone.guitar,
                        pickup: tone.pickup,
                        pedals: tone.pedals,
                        notes: tone.notes
                    )
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingSignIn) {
            SignInSheet()
        }
        .confirmationDialog(
            "Delete this AI tone?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                aiCache.delete(tone)
                dismiss()
            }
        }
    }

    private func publish() {
        guard let userID = session.userID else {
            showingSignIn = true
            return
        }
        isPublishing = true
        publishError = nil
        let draft = ToneDraft(
            song: tone.asCatalogSong,
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
                isPublished = true
            } catch {
                publishError = error.localizedDescription
            }
            isPublishing = false
        }
    }
}

/// Compact row used in Profile and song pages.
struct SavedAIToneRow: View {
    let tone: SavedAITone
    var showSong: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            SongArtworkView(genre: tone.genre, artworkURL: tone.artworkURL)
            VStack(alignment: .leading, spacing: 2) {
                Text(tone.name)
                    .lineLimit(1)
                if showSong {
                    Text("\(tone.songTitle) · \(tone.artistName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Label("AI · \(tone.createdAt.formatted(date: .numeric, time: .omitted))", systemImage: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
            Spacer()
            CharacterBadge(character: tone.character)
        }
        .padding(.vertical, 2)
    }
}
