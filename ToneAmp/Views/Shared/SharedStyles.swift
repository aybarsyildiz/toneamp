import SwiftUI

extension Genre {
    var tint: Color {
        switch self {
        case .rock: return .orange
        case .hardRock: return .red
        case .metal: return .indigo
        case .grunge: return .teal
        case .bluesRock: return .blue
        case .alternative: return .purple
        case .funkRock: return .pink
        case .psychedelic: return .mint
        case .anatolian: return .brown
        }
    }
}

extension EffectType {
    var tint: Color {
        switch self {
        case .overdrive: return .orange
        case .distortion: return .red
        case .fuzz: return .purple
        case .boost: return .green
        case .delay: return .blue
        case .reverb: return .cyan
        case .chorus: return .teal
        case .phaser: return .indigo
        case .flanger: return .mint
        case .wah: return .pink
        case .compressor: return .gray
        case .octave: return .brown
        case .eq: return .gray
        }
    }
}

/// Settings-app-style icon: white symbol on a tinted rounded square.
struct EffectIconView: View {
    let type: EffectType

    var body: some View {
        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [type.tint.opacity(0.85), type.tint],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 29, height: 29)
            .overlay {
                Image(systemName: type.symbolName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

extension ToneCharacter {
    var tint: Color {
        switch self {
        case .clean: return .blue
        case .crunch: return .orange
        case .overdrive: return .brown
        case .highGain: return .red
        case .fuzz: return .purple
        case .lead: return .pink
        }
    }

    var symbolName: String {
        switch self {
        case .clean: return "sparkles"
        case .crunch: return "bolt.fill"
        case .overdrive: return "dial.max"
        case .highGain: return "flame.fill"
        case .fuzz: return "waveform.path"
        case .lead: return "guitars.fill"
        }
    }
}

/// Song "cover": real album artwork when a URL is available (iTunes),
/// otherwise a genre-tinted gradient placeholder.
struct SongArtworkView: View {
    let genre: Genre
    var artworkURL: URL? = nil
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [genre.tint.opacity(0.85), genre.tint.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "guitars.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundStyle(.white.opacity(0.9))
            }
    }
}

/// Interactive 1–5 star control (pass `onTap`) or read-only display.
struct RatingStarsView: View {
    var rating: Int
    var size: CGFloat = 22
    var onTap: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1..<6) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.4))
                    .symbolEffect(.bounce, value: rating >= star ? rating : 0)
                    .onTapGesture {
                        onTap?(star)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) of 5 stars")
    }
}

/// Plain-text tone sheet for ShareLink.
func toneShareText(
    songTitle: String,
    artist: String,
    toneName: String,
    amp: String,
    settings: AmpSettings,
    guitar: String,
    pickup: String,
    pedals: [EffectPedal],
    notes: String
) -> String {
    var lines: [String] = []
    lines.append("🎸 \(toneName) — \(songTitle) by \(artist)")
    lines.append("Amp: \(amp)")
    let knobs = settings.knobs
        .map { "\($0.label) \($0.value.formatted(.number.precision(.fractionLength(0...1))))" }
        .joined(separator: " · ")
    lines.append("Settings: \(knobs)")
    if !guitar.isEmpty {
        lines.append("Guitar: \(guitar) (\(pickup))")
    }
    if pedals.isEmpty {
        lines.append("Pedals: straight into the amp")
    } else {
        for pedal in pedals {
            let controls = pedal.controls
                .map { "\($0.name) \($0.value.formatted(.number.precision(.fractionLength(0...1))))" }
                .joined(separator: ", ")
            lines.append("Pedal: \(pedal.name)\(controls.isEmpty ? "" : " — " + controls)")
        }
    }
    if !notes.isEmpty {
        lines.append("Notes: \(notes)")
    }
    lines.append("— dialed in with ToneAmp")
    return lines.joined(separator: "\n")
}

/// Shown when a non-Pro user taps a Pro feature.
struct ProTeaserSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 54))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, options: .repeating)
                .padding(.top, 40)
            Text("ToneAmp Pro")
                .font(.title2.bold())
            Text("Identify Tones asks the AI tone engine to build a knob-by-knob tone sheet — amp, pedals, and all — for any song in the catalog.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Text("Subscriptions are coming soon. Until then, enable the Pro Preview in Settings.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
    }
}

/// Compact "★ 4.5 (12)" label for list rows.
struct RatingSummaryLabel: View {
    let average: Double?
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(.yellow)
            if let average {
                Text(average.formatted(.number.precision(.fractionLength(1))))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text("(\(count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No ratings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CharacterBadge: View {
    let character: ToneCharacter

    var body: some View {
        Label(character.rawValue, systemImage: character.symbolName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(character.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(character.tint)
    }
}

struct SongRow: View {
    @Environment(FavoritesStore.self) private var favorites
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            SongArtworkView(genre: song.genre, artworkURL: song.artworkURL, size: 52)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                if favorites.isFavorite(song) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Favorite")
                }
                if song.tones.count > 1 {
                    Text("\(song.tones.count) tones")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
