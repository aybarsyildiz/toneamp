import SwiftUI

/// Search-first gear selection: type a model, tap to add. Used in
/// onboarding and from the rig editor.
struct GearPickerView: View {
    @Environment(RigStore.self) private var rigStore
    @State private var query = ""

    var showsSelectedRow = true

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sections: [(category: GearItem.Category, items: [GearItem])] {
        let matching: [GearItem]
        if trimmedQuery.isEmpty {
            matching = GearCatalog.popularGear
        } else {
            matching = GearCatalog.popularGear.filter {
                $0.name.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
        return GearItem.Category.allCases.compactMap { category in
            let items = matching.filter { $0.category == category }
            return items.isEmpty ? nil : (category, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search your gear — e.g. GT-8, Katana, Les Paul", text: $query)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 8)

            if showsSelectedRow && !rigStore.selectedGearItems.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(rigStore.selectedGearItems) { item in
                            Button {
                                withAnimation(.snappy) {
                                    rigStore.toggle(item)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(item.name)
                                        .lineLimit(1)
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.14), in: Capsule())
                                .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
                .padding(.bottom, 6)
            }

            List {
                ForEach(sections, id: \.category) { section in
                    Section(section.category.rawValue) {
                        ForEach(section.items) { item in
                            Button {
                                withAnimation(.snappy) {
                                    rigStore.toggle(item)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.category.symbol)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    Text(item.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if rigStore.isSelected(item) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    } else {
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .sensoryFeedback(.selection, trigger: rigStore.isSelected(item))
                        }
                    }
                }
                if sections.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No match for \u{201C}\(trimmedQuery)\u{201D} — add it as custom gear:")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                customAddButton("Guitar") {
                                    rigStore.rig.guitarText = appended(trimmedQuery, to: rigStore.rig.guitarText)
                                }
                                customAddButton("Amp") {
                                    rigStore.rig.ampText = appended(trimmedQuery, to: rigStore.rig.ampText)
                                }
                                customAddButton("Pedal/FX") {
                                    rigStore.rig.pedalsText = appended(trimmedQuery, to: rigStore.rig.pedalsText)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private func customAddButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) {
                action()
                query = ""
            }
        } label: {
            Text("+ \(label)")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
    }

    private func appended(_ name: String, to list: String) -> String {
        list.isEmpty ? name : list + ", " + name
    }
}
