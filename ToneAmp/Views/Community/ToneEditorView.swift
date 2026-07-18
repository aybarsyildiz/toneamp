import SwiftUI

/// Create and publish a tone for a canonical catalog song.
struct ToneEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    let song: CatalogSong
    var onPublished: () -> Void

    @State private var toneName = ""
    @State private var character: ToneCharacter = .crunch
    @State private var ampName = ""
    @State private var gain = 5.0
    @State private var bass = 5.0
    @State private var mid = 5.0
    @State private var treble = 5.0
    @State private var presence = 5.0
    @State private var reverb = 0.0
    @State private var guitar = ""
    @State private var pickup = ""
    @State private var pedals: [EffectPedal] = []
    @State private var notes = ""
    @State private var showingPedalEditor = false
    @State private var isPublishing = false
    @State private var errorMessage: String?
    @State private var showingSignIn = false

    private var canPublish: Bool {
        !toneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !ampName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isPublishing
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        SongArtworkView(genre: song.genre, artworkURL: song.artworkURL)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.trackName)
                                .lineLimit(1)
                            Text(song.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section("Tone") {
                    TextField("Name — e.g. Main Riff, Solo", text: $toneName)
                    Picker("Character", selection: $character) {
                        ForEach(ToneCharacter.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                }

                Section("Amp") {
                    TextField("Amp — e.g. Fender Deluxe Reverb", text: $ampName)
                    KnobSliderRow(label: "Gain", value: $gain)
                    KnobSliderRow(label: "Bass", value: $bass)
                    KnobSliderRow(label: "Mid", value: $mid)
                    KnobSliderRow(label: "Treble", value: $treble)
                    KnobSliderRow(label: "Presence", value: $presence)
                    KnobSliderRow(label: "Reverb", value: $reverb)
                }

                Section("Guitar") {
                    TextField("Guitar — e.g. Stratocaster", text: $guitar)
                    TextField("Pickup — e.g. Bridge humbucker", text: $pickup)
                }

                Section("Pedals & Effects") {
                    ForEach(pedals) { pedal in
                        PedalRow(pedal: pedal)
                    }
                    .onDelete { offsets in
                        pedals.remove(atOffsets: offsets)
                    }
                    Button {
                        showingPedalEditor = true
                    } label: {
                        Label("Add Pedal", systemImage: "plus.circle")
                    }
                }

                Section("Notes") {
                    TextField(
                        "Tuning, technique, what makes it work…",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                }

                Section {
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
                                Label("Publish Tone", systemImage: "paperplane.fill")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canPublish)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                    } else {
                        Text("Published under your name (\(session.authorName)) for everyone to see and rate.")
                    }
                }
            }
            .navigationTitle("New Tone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPedalEditor) {
                PedalEditorView { pedal in
                    pedals.append(pedal)
                }
            }
            .sheet(isPresented: $showingSignIn) {
                SignInSheet()
            }
        }
    }

    private func publish() {
        guard let userID = session.userID else {
            showingSignIn = true
            return
        }
        isPublishing = true
        errorMessage = nil
        let draft = ToneDraft(
            song: song,
            toneName: toneName.trimmingCharacters(in: .whitespacesAndNewlines),
            character: character,
            ampName: ampName.trimmingCharacters(in: .whitespacesAndNewlines),
            settings: AmpSettings(
                gain: gain,
                bass: bass,
                mid: mid,
                treble: treble,
                presence: presence,
                reverb: reverb
            ),
            guitar: guitar.trimmingCharacters(in: .whitespacesAndNewlines),
            pickup: pickup.trimmingCharacters(in: .whitespacesAndNewlines),
            pedals: pedals,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task { @MainActor in
            do {
                try await CommunityService.publish(
                    draft,
                    authorName: session.authorName,
                    authorID: userID
                )
                onPublished()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isPublishing = false
        }
    }
}

struct KnobSliderRow: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 72, alignment: .leading)
            Slider(value: $value, in: 0...10, step: 0.5)
            Text(value.formatted(.number.precision(.fractionLength(0...1))))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(width: 34, alignment: .trailing)
        }
    }
}

/// Sheet for building one pedal: name, type, its knobs, and a usage note.
struct PedalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (EffectPedal) -> Void

    @State private var name = ""
    @State private var type: EffectType = .overdrive
    @State private var controls: [PedalControl] = []
    @State private var newControlName = ""
    @State private var note = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pedal") {
                    TextField("Name — e.g. Tube Screamer", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(EffectType.allCases, id: \.self) { value in
                            Label(value.displayName, systemImage: value.symbolName).tag(value)
                        }
                    }
                }

                Section("Knobs") {
                    ForEach($controls) { $control in
                        KnobSliderRow(label: $control.name.wrappedValue, value: $control.value)
                    }
                    .onDelete { offsets in
                        controls.remove(atOffsets: offsets)
                    }
                    HStack {
                        TextField("Knob name — e.g. Drive", text: $newControlName)
                        Button {
                            let trimmed = newControlName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            controls.append(PedalControl(name: trimmed, value: 5))
                            newControlName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newControlName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section("Note") {
                    TextField("How it's used — e.g. always on, solo boost", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Pedal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(
                            EffectPedal(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                type: type,
                                controls: controls,
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }
}
