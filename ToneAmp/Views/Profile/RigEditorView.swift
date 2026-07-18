import SwiftUI

/// Toggleable chip used for rig selection (and anywhere multi-select lives).
struct ToggleChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy) {
                action()
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.tertiarySystemFill)),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Wrapping grid of chips.
struct ChipFlow: View {
    let items: [String]
    let isSelected: (String) -> Bool
    let toggle: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 118), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                ToggleChip(label: item, isSelected: isSelected(item)) {
                    toggle(item)
                }
            }
        }
    }
}

/// Full rig editor — guitars (multi), amp (single), pedals (multi).
struct RigEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RigStore.self) private var rigStore
    @State private var showingGearPicker = false

    var body: some View {
        @Bindable var store = rigStore
        NavigationStack {
            Form {
                Section {
                    Button {
                        showingGearPicker = true
                    } label: {
                        Label("Search Popular Gear", systemImage: "magnifyingglass")
                    }
                } footer: {
                    Text("The fastest way — find your exact models and tap to add.")
                }

                Section {
                    TextField("Guitar — e.g. Fender Player Strat HSS", text: $store.rig.guitarText)
                    TextField("Amp — e.g. Boss Katana 50 MkII", text: $store.rig.ampText)
                    TextField("Pedals / multi-FX — e.g. Boss GT-8, TS9, DD-8", text: $store.rig.pedalsText, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Describe Your Exact Gear")
                } footer: {
                    Text("Free text — the Pro tone engine reads this to write tips for your specific models (multi-FX units like a GT-8 belong here or in the chip below). The quick picks power instant local tips.")
                }

                Section {
                    ChipFlow(
                        items: GearCatalog.guitars,
                        isSelected: { rigStore.rig.guitars.contains($0) },
                        toggle: { toggleGuitar($0) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                } header: {
                    Text("Your Guitars")
                } footer: {
                    Text("Pick everything you play — tips adapt to your pickups.")
                }

                Section("Your Amp") {
                    ChipFlow(
                        items: GearCatalog.amps,
                        isSelected: { rigStore.rig.amp == $0 },
                        toggle: { amp in
                            rigStore.rig.amp = rigStore.rig.amp == amp ? "" : amp
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                }

                Section {
                    ToggleChip(
                        label: GearCatalog.multiFXLabel,
                        isSelected: rigStore.rig.pedalTypes.contains(GearCatalog.multiFXKey)
                    ) {
                        if let index = rigStore.rig.pedalTypes.firstIndex(of: GearCatalog.multiFXKey) {
                            rigStore.rig.pedalTypes.remove(at: index)
                        } else {
                            rigStore.rig.pedalTypes.append(GearCatalog.multiFXKey)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
                    ChipFlow(
                        items: GearCatalog.pedalOptions.map { $0.displayName },
                        isSelected: { name in
                            guard let type = GearCatalog.pedalOptions.first(where: { $0.displayName == name }) else { return false }
                            return rigStore.rig.pedalTypes.contains(type.rawValue)
                        },
                        toggle: { name in
                            guard let type = GearCatalog.pedalOptions.first(where: { $0.displayName == name }) else { return }
                            togglePedal(type)
                        }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                } header: {
                    Text("Your Pedals & Effects")
                } footer: {
                    Text("A multi-FX unit counts as owning everything — tone pages will suggest a patch chain instead of individual pedals.")
                }
            }
            .navigationTitle("My Rig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingGearPicker) {
                NavigationStack {
                    GearPickerView()
                        .navigationTitle("Add Gear")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingGearPicker = false
                                }
                            }
                        }
                }
            }
        }
    }

    private func toggleGuitar(_ guitar: String) {
        if let index = rigStore.rig.guitars.firstIndex(of: guitar) {
            rigStore.rig.guitars.remove(at: index)
        } else {
            rigStore.rig.guitars.append(guitar)
        }
    }

    private func togglePedal(_ type: EffectType) {
        if let index = rigStore.rig.pedalTypes.firstIndex(of: type.rawValue) {
            rigStore.rig.pedalTypes.remove(at: index)
        } else {
            rigStore.rig.pedalTypes.append(type.rawValue)
        }
    }
}

/// Shared "For Your Rig" tips block used by tone detail screens.
struct RigTipsView: View {
    @Environment(RigStore.self) private var rigStore
    let pickup: String
    let amp: String
    let pedals: [EffectPedal]

    @State private var showingEditor = false

    var body: some View {
        if rigStore.rig.isConfigured {
            let tips = RigAdvisor.tips(pickup: pickup, amp: amp, pedals: pedals, rig: rigStore.rig)
            if tips.isEmpty {
                Label("Your rig covers this tone — dial the values in as shown.", systemImage: "checkmark.seal.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                ForEach(tips, id: \.self) { tip in
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
        } else {
            Button {
                showingEditor = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "guitars")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Set up your rig")
                        Text("Get tips translated to your own guitar, amp, and pedals.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                MyRigView()
            }
        }
    }
}
