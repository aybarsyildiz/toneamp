import SwiftUI

extension GearItem.Category: Identifiable {
    public var id: String { rawValue }
}

/// The rig as a visual signal chain: guitar → effects → amp/output.
/// Styled like a native grouped list — icon squircles, hairline rows —
/// with a live signal dot running the cable once the chain is connected.
struct MyRigView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RigStore.self) private var rigStore

    /// False when hosted as a tab (large title, no Done button).
    var showsDone: Bool = true

    @State private var pickerCategory: GearItem.Category?
    @State private var showingAdvanced = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    sectionHeader("Signal Chain")

                    RigSlotCard(
                        symbol: "guitars.fill",
                        title: hasGuitar ? guitarTitle : "Add Your Guitar",
                        subtitle: hasGuitar ? "Guitar" : nil,
                        isFilled: hasGuitar
                    ) {
                        pickerCategory = .guitar
                    }

                    SignalConnector(isLive: hasGuitar)

                    effectsCard

                    SignalConnector(isLive: hasGuitar && hasOutput)

                    RigSlotCard(
                        symbol: outputSymbol,
                        title: hasOutput ? outputTitle : "Add Your Amp",
                        subtitle: outputSubtitle,
                        isFilled: hasOutput
                    ) {
                        pickerCategory = .amp
                    }

                    Text("Every tone in ToneAmp gets translated to this rig.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Rig")
            .navigationBarTitleDisplayMode(showsDone ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Advanced") {
                        showingAdvanced = true
                    }
                }
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.leading, 16)
            .padding(.bottom, 2)
    }

    // MARK: Slot state

    private var hasGuitar: Bool {
        !rigStore.rig.guitars.isEmpty || !rigStore.rig.guitarText.isEmpty
    }

    private var guitarTitle: String {
        let all = ([rigStore.rig.guitarText] + rigStore.rig.guitars).filter { !$0.isEmpty }
        return all.joined(separator: ", ")
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
        return all.joined(separator: " · ")
    }

    private var outputSubtitle: String? {
        guard hasOutput else { return nil }
        return isDirect ? "Direct — no amp needed" : "Amp"
    }

    // MARK: Effects card

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

    private var effectsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if fxTokens.isEmpty {
                Button {
                    pickerCategory = .pedal
                } label: {
                    HStack(spacing: 12) {
                        SlotIcon(symbol: "bolt.fill", isFilled: false)
                        Text("Add Pedals or a Multi-FX")
                            .font(.body)
                            .foregroundStyle(.tint)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                ForEach(Array(fxTokens.enumerated()), id: \.element) { index, token in
                    HStack(spacing: 12) {
                        SlotIcon(symbol: "bolt.fill", isFilled: true)
                        Text(token)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            withAnimation(.snappy) {
                                rigStore.rig.pedalsText = RigStore.togglingToken(token, in: rigStore.rig.pedalsText)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    if index < fxTokens.count - 1 {
                        Divider()
                            .padding(.leading, 55)
                    }
                }
                Divider()
                    .padding(.leading, 55)
                Menu {
                    Button {
                        pickerCategory = .pedal
                    } label: {
                        Label("Add Pedal", systemImage: "bolt.fill")
                    }
                    Button {
                        pickerCategory = .multiFX
                    } label: {
                        Label("Add Multi-FX / Modeler", systemImage: "square.grid.3x3.fill")
                    }
                } label: {
                    HStack(spacing: 12) {
                        SlotIcon(symbol: "plus", isFilled: false)
                        Text("Add Effect")
                            .font(.body)
                            .foregroundStyle(.tint)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                if !categoryCapsules.isEmpty {
                    Divider()
                        .padding(.leading, 55)
                    HStack(spacing: 6) {
                        Text("Covers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(categoryCapsules.prefix(5), id: \.self) { name in
                            Text(name)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

/// Settings-style icon squircle.
private struct SlotIcon: View {
    let symbol: String
    let isFilled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isFilled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.tertiarySystemFill)))
                .frame(width: 29, height: 29)
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isFilled ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
        }
    }
}

/// One slot in the chain (guitar / amp) as a single grouped-list-style row.
private struct RigSlotCard: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let isFilled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SlotIcon(symbol: symbol, isFilled: isFilled)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(isFilled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isFilled ? "chevron.right" : "plus.circle.fill")
                    .font(isFilled ? .footnote.weight(.semibold) : .body)
                    .foregroundStyle(isFilled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
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
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 2, height: 26)
            if isLive {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                    .offset(y: pulse ? 11 : -11)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 26)
        .onAppear {
            pulse = true
        }
    }
}
