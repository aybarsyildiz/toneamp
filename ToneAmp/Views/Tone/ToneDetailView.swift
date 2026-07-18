import SwiftUI

struct ToneDetailView: View {
    let tone: Tone
    let song: Song

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
        }
        .navigationTitle(tone.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: toneShareText(
                        songTitle: song.title,
                        artist: song.artist,
                        toneName: tone.name,
                        amp: tone.amp,
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
