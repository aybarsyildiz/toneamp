import SwiftUI

/// Grid of amp dials rendered with the system circular Gauge — the same
/// component Apple uses for Watch-style complications, so it inherits
/// Dynamic Type scaling, dark mode, and accessibility for free.
struct AmpPanelView: View {
    let settings: AmpSettings

    private let columns = [
        GridItem(.adaptive(minimum: 74), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(settings.knobs, id: \.label) { knob in
                KnobView(label: knob.label, value: knob.value)
            }
        }
        .padding(.vertical, 8)
    }
}

struct KnobView: View {
    let label: String
    let value: Double

    /// Dials sweep up from zero on appear — the "amp warming up" moment.
    @State private var animatedValue: Double = 0

    private var formattedValue: String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Gain sweeps green→red like a drive meter; EQ dials stay on the accent.
    private var tintGradient: Gradient {
        if label == "Gain" {
            return Gradient(colors: [.green, .yellow, .orange, .red])
        }
        return Gradient(colors: [Color.accentColor.opacity(0.45), Color.accentColor])
    }

    var body: some View {
        VStack(spacing: 6) {
            Gauge(value: animatedValue, in: 0...10) {
                Text(label)
            } currentValueLabel: {
                Text(formattedValue)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(tintGradient)
            Text(label.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.25)) {
                animatedValue = value
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text("\(formattedValue) of 10"))
    }
}

/// Compact dial for a single pedal knob.
struct PedalControlDial: View {
    let control: PedalControl
    let tint: Color

    private var formattedValue: String {
        control.value.formatted(.number.precision(.fractionLength(0...1)))
    }

    var body: some View {
        VStack(spacing: 2) {
            Gauge(value: control.value, in: 0...10) {
                Text(control.name)
            } currentValueLabel: {
                Text(formattedValue)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(Gradient(colors: [tint.opacity(0.45), tint]))
            .scaleEffect(0.8)
            .frame(width: 48, height: 48)
            Text(control.name.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(control.name))
        .accessibilityValue(Text("\(formattedValue) of 10"))
    }
}
