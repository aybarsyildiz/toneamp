import SwiftUI

struct ToneDetailView: View {
    let tone: Tone
    let song: Song

    private var cardPayload: ToneCardPayload {
        ToneCardPayload(
            songTitle: song.title,
            artist: song.artist,
            toneName: tone.name,
            character: tone.character,
            ampName: tone.amp,
            settings: tone.settings,
            guitar: tone.guitar,
            pickup: tone.pickup,
            pedalNames: tone.pedals.map(\.name),
            key: song.key
        )
    }

    var body: some View {
        List {
            Section("Amp") {
                HStack {
                    Label(tone.amp, systemImage: "amplifier")
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

            Section("For Your Rig") {
                RigTipsView(pickup: tone.pickup, amp: tone.amp, pedals: tone.pedals)
                AdaptToMyGearButton(
                    input: ToneAdaptationInput(
                        trackID: ToneAdaptationInput.syntheticTrackID(for: song.id),
                        songTitle: song.title,
                        artist: song.artist,
                        albumName: song.album,
                        year: song.year,
                        genre: song.genre,
                        artworkURL: song.artworkURL,
                        toneName: tone.name,
                        ampName: tone.amp,
                        settings: tone.settings,
                        guitar: tone.guitar,
                        pickup: tone.pickup,
                        pedals: tone.pedals,
                        notes: tone.notes
                    )
                )
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

            Section("Notes") {
                Text(tone.notes)
                    .font(.callout)
            }

            Section {
                NailedItButton(toneKey: "lib|\(song.id)|\(tone.id)")
            }
        }
        .navigationTitle(tone.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ToneCardShareLink(payload: cardPayload)
            }
        }
    }
}

struct PedalRow: View {
    let pedal: EffectPedal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                EffectIconView(type: pedal.type)
                VStack(alignment: .leading, spacing: 1) {
                    Text(pedal.name)
                    Text(pedal.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if !pedal.controls.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(pedal.controls) { control in
                        PedalControlDial(control: control, tint: pedal.type.tint)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            if !pedal.note.isEmpty {
                Text(pedal.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
