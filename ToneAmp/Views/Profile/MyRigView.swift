import SwiftUI

extension GearItem.Category: Identifiable {
    public var id: String { rawValue }
}

/// The rig as a visual signal chain: guitar → effects → amp/output.
/// Tap any slot to fill it; the cable pulses once something's connected.
struct MyRigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RigStore.self) private var rigStore

    @State private var pickerCategory: GearItem.Category?
    @State private var showingAdvanced = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text("Your signal chain")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    RigSlotCard(
                        symbol: "guitars.fill",
                        title: guitarTitle,
                        subtitle: guitarSubtitle,
                        isFilled: hasGuitar
                    ) {
                        pickerCategory = .guitar
                    }

                    SignalConnector(isLive: hasGuitar)

                    effectsBoard

                    SignalConnector(isLive: hasGuitar && hasOutput)

                    RigSlotCard(
                        symbol: outputSymbol,
                        title: outputTitle,
                        subtitle: outputSubtitle,
                        isFilled: hasOutput
                    ) {
                        pickerCategory = .amp
                    }

                    Text("Every tone in ToneAmp gets translated to this rig.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 22)
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 18)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Rig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Advanced") {
                        showingAdvanced = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $pickerCategory) { category in
                NavigationStack {
                    GearPickerView(fixedCategory: category)
                        .navigationTitle("Add \(category.rawValue)")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    pickerCategory = nil
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingAdvanced) {
                RigEditorView()
            }
        }
    }

    // MARK: Slot state

    private var hasGuitar: Bool {
        !rigStore.rig.guitars.isEmpty || !rigStore.rig.guitarText.isEmpty
    }

    private var guitarTitle: String {
        let all = ([rigStore.rig.guitarText] + rigStore.rig.guitars).filter { !$0.isEmpty }
        return all.isEmpty ? "Add your guitar" : all.joined(separator: ", ")
    }

    private var guitarSubtitle: String {
        hasGuitar ? "Tap to change" : "What do you play?"
    }

    private var hasOutput: Bool {
        !rigStore.rig.amp.isEmpty || !rigStore.rig.ampText.isEmpty
    }

    private var isDirect: Bool {
        rigStore.rig.ampText.localizedCaseInsensitiveContains("audio interface")
            || rigStore.rig.ampText.localizedCaseInsensitiveContains("headphones")
    }

    private var outputSymbol: String {
        isDirect ? "desktopcomputer" : "amplifier"
    }

    private var outputTitle: String {
        let all = ([rigStore.rig.ampText] + [rigStore.rig.amp]).filter { !$0.isEmpty }
        return all.isEmpty ? "Add your amp" : all.joined(separator: " · ")
    }

    private var outputSubtitle: String {
        if !hasOutput {
            return "Amp, modeler, or direct to PC"
        }
        return isDirect ? "Direct — no amp needed" : "Tap to change"
    }

    // MARK: Effects board

    private var fxTokens: [String] {
        rigStore.rig.pedalsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var categoryCapsules: [String] {
        rigStore.rig.pedalTypes
            .filter { $0 != GearCatalog.multiFXKey }
            .compactMap { raw in
                EffectType(rawValue: raw)?.displayName
            }
    }

    private var effectsBoard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Effects", systemImage: "bolt.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button {
                        pickerCategory = .pedal
                    } label: {
                        Label("Add pedal", systemImage: "bolt.fill")
                    }
                    Button {
                        pickerCategory = .multiFX
                    } label: {
                        Label("Add multi-FX / modeler", systemImage: "square.grid.3x3.fill")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }

            if fxTokens.isEmpty && categoryCapsules.isEmpty {
                Button {
                    pickerCategory = .pedal
                } label: {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add pedals or a multi-FX")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                            .foregroundStyle(Color(.systemGray3))
                    )
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(fxTokens, id: \.self) { token in
                        FXTile(name: token) {
                            withAnimation(.snappy) {
                                rigStore.rig.pedalsText = RigStore.togglingToken(token, in: rigStore.rig.pedalsText)
                            }
                        }
                    }
                }
                if !categoryCapsules.isEmpty {
                    HStack(spacing: 6) {
                        Text("Covers:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        ForEach(categoryCapsules.prefix(5), id: \.self) { name in
                            Text(name)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// One slot in the chain (guitar / amp).
private struct RigSlotCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let isFilled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isFilled ? Color.accentColor.opacity(0.14) : Color(.tertiarySystemFill))
                        .frame(width: 46, height: 46)
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(isFilled ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isFilled ? .primary : Color.accentColor)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isFilled ? "chevron.right" : "plus.circle.fill")
                    .foregroundStyle(isFilled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isFilled {
                        AnyView(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    } else {
                        AnyView(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                .foregroundStyle(Color(.systemGray3))
                        )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isFilled)
    }
}

/// The cable between slots — a signal dot travels it when the chain is live.
private struct SignalConnector: View {
    let isLive: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray4))
                .frame(width: 3, height: 34)
            if isLive {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                    .offset(y: pulse ? 14 : -14)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse)
            }
        }
        .frame(height: 34)
        .onAppear {
            pulse = true
        }
    }
}

/// A pedal (or multi-FX) as a little stompbox tile.
private struct FXTile: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
