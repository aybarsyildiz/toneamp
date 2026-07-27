import SwiftUI

/// One setlist: library songs, community tones, and saved AI tones in order,
/// each opening its full tone sheet.
struct SetlistDetailView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AIToneCacheStore.self) private var aiCache
    @Environment(SetlistStore.self) private var setlistStore
    let setlistID: UUID

    private var setlist: Setlist? {
        setlistStore.setlists.first { $0.id == setlistID }
    }

    var body: some View {
        Group {
            if let setlist, !setlist.items.isEmpty {
                List {
                    ForEach(setlist.items) { item in
                        row(for: item)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    setlistStore.remove(itemID: item.id, from: setlistID)
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                }
                            }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView {
                    Label("Empty Setlist", systemImage: "music.note.list")
                } description: {
                    Text("Add songs, community tones, or your AI tones from their pages — look for the \(Image(systemName: "music.note.list")) button.")
                }
            }
        }
        .navigationTitle(setlist?.name ?? "Setlist")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SetlistItem.self) { item in
            CommunityToneLoaderView(item: item)
        }
    }

    @ViewBuilder
    private func row(for item: SetlistItem) -> some View {
        switch item.kind {
        case .song:
            if let song = library.song(id: item.id) {
                NavigationLink(value: song) {
                    SongRow(song: song)
                }
            } else {
                unavailableRow(item)
            }
        case .aiTone:
            if let saved = aiCache.tones.first(where: { $0.id.uuidString == item.id }) {
                NavigationLink(value: saved) {
                    SavedAIToneRow(tone: saved)
                }
            } else {
                unavailableRow(item)
            }
        case .community:
            NavigationLink(value: item) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .lineLimit(1)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Label("Community", systemImage: "person.2")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func unavailableRow(_ item: SetlistItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title.isEmpty ? "Unavailable" : item.title)
            Text("No longer available")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
    }
}

/// Setlist entries only carry a community tone's record ID — fetch the full
/// tone before showing the detail screen.
struct CommunityToneLoaderView: View {
    let item: SetlistItem

    @State private var tone: CommunityTone?
    @State private var failed = false

    var body: some View {
        Group {
            if let tone {
                CommunityToneDetailView(tone: tone)
            } else if failed {
                ContentUnavailableView {
                    Label("Tone Unavailable", systemImage: "wifi.exclamationmark")
                } description: {
                    Text("\u{201C}\(item.title)\u{201D} couldn't be loaded. It may have been removed, or you may be offline.")
                }
            } else {
                ProgressView()
                    .task {
                        tone = try? await CommunityService.tone(id: item.id)
                        if tone == nil { failed = true }
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
