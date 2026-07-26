import SwiftUI

/// One setlist: its songs in order, each opening the full tone sheet.
struct SetlistDetailView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(SetlistStore.self) private var setlistStore
    let setlistID: UUID

    private var setlist: Setlist? {
        setlistStore.setlists.first { $0.id == setlistID }
    }

    private var songs: [Song] {
        (setlist?.songIDs ?? []).compactMap { library.song(id: $0) }
    }

    var body: some View {
        Group {
            if songs.isEmpty {
                ContentUnavailableView {
                    Label("Empty Setlist", systemImage: "music.note.list")
                } description: {
                    Text("Open any song in the Library and use the ••• menu → Add to Setlist.")
                }
            } else {
                List {
                    ForEach(songs) { song in
                        NavigationLink(value: song) {
                            SongRow(song: song)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                setlistStore.remove(songID: song.id, from: setlistID)
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(setlist?.name ?? "Setlist")
        .navigationBarTitleDisplayMode(.inline)
    }
}
