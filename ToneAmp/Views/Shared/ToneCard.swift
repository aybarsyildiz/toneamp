import SwiftUI
import UIKit

/// Everything a shareable card needs, buildable from library, community,
/// or saved-AI tones.
struct ToneCardPayload {
    let songTitle: String
    let artist: String
    let toneName: String
    let character: ToneCharacter
    let ampName: String
    let settings: AmpSettings
    let guitar: String
    let pickup: String
    let pedalNames: [String]
    var key: String? = nil
}

/// The shareable tone card. Deliberately quiet: one flat ground, one accent,
/// hairlines, and typography doing all the work — no gradients, no chrome.
struct ToneCardView: View {
    let payload: ToneCardPayload

    private let ground = Color(red: 0.039, green: 0.035, blue: 0.031)
    private let bone = Color(red: 0.945, green: 0.925, blue: 0.882)
    private let accent = Color(red: 1.0, green: 0.416, blue: 0.102)
    private let hairline = Color.white.opacity(0.14)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Masthead
            HStack {
                Text("TONEAMP — TONE SHEET")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .kerning(2.5)
                    .foregroundStyle(accent)
                Spacer()
                Text(payload.character.rawValue.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .kerning(1.5)
                    .foregroundStyle(ground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent)
            }
            .padding(.bottom, 26)

            // Song
            Text(payload.songTitle)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(bone)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            HStack(spacing: 10) {
                Text(payload.artist)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(bone.opacity(0.6))
                if let key = payload.key, !key.isEmpty {
                    Text("· \(key)")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(bone.opacity(0.4))
                }
            }
            .padding(.top, 4)

            divider.padding(.vertical, 22)

            // Tone + amp
            Text(payload.toneName.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .kerning(2)
                .foregroundStyle(bone.opacity(0.45))
            Text(payload.ampName)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(bone)
                .padding(.top, 4)

            // Knob values — big mono numbers, six clean columns.
            HStack(spacing: 0) {
                knob("GAIN", payload.settings.gain)
                knob("BASS", payload.settings.bass)
                knob("MID", payload.settings.mid)
                knob("TREBLE", payload.settings.treble)
                knob("PRES", payload.settings.presence ?? 0)
                knob("REV", payload.settings.reverb ?? 0)
            }
            .padding(.top, 18)

            divider.padding(.vertical, 22)

            // Signal chain
            if !payload.pedalNames.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(payload.pedalNames.prefix(5).enumerated()), id: \.offset) { i, name in
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", i + 1))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundStyle(accent)
                            Text(name)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(bone.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                Text("Straight into the amp")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(bone.opacity(0.5))
            }

            if !payload.guitar.isEmpty {
                Text("\(payload.guitar)\(payload.pickup.isEmpty ? "" : " — \(payload.pickup)")")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(bone.opacity(0.45))
                    .lineLimit(1)
                    .padding(.top, 14)
            }

            Spacer(minLength: 20)

            // Footer
            divider.padding(.bottom, 16)
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(accent)
                            .frame(width: 22, height: 22)
                        Circle()
                            .fill(ground)
                            .frame(width: 13, height: 13)
                    }
                    Text("ToneAmp")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(bone)
                }
                Spacer()
                Text("toneamp.netnucleus.solutions")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(bone.opacity(0.4))
            }
        }
        .padding(44)
        .frame(width: 540, height: 675, alignment: .top)
        .background(ground)
    }

    private var divider: some View {
        Rectangle().fill(hairline).frame(height: 1)
    }

    private func knob(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 4) {
            Text(value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value))
                .font(.system(size: 30, weight: .medium, design: .monospaced))
                .foregroundStyle(bone)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .kerning(1.2)
                .foregroundStyle(bone.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

/// Renders the card at 2x (1080×1350 — Instagram-friendly 4:5) and shares.
struct ShareToneCardButton: View {
    let payload: ToneCardPayload

    @State private var shareImage: UIImage?
    @State private var showingShare = false

    var body: some View {
        Button {
            let renderer = ImageRenderer(content: ToneCardView(payload: payload))
            renderer.scale = 2
            if let image = renderer.uiImage {
                shareImage = image
                showingShare = true
            }
        } label: {
            Label("Share Tone Card", systemImage: "square.and.arrow.up.on.square")
                .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingShare) {
            if let shareImage {
                ActivitySheet(items: [shareImage])
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
        }
    }
}

/// Thin UIActivityViewController wrapper — ShareLink can't render lazily.
private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
