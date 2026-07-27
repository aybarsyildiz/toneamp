import SwiftUI

/// The one way anything gets into a setlist — a toolbar menu shared by song,
/// community-tone, and AI-tone screens. Creating a list inline adds the
/// current item to it immediately.
struct SetlistToolbarMenu: View {
    let item: SetlistItem

    @Environment(SetlistStore.self) private var setlistStore
    @State private var showingNew = false
    @State private var newName = ""

    var body: some View {
        Menu {
            ForEach(setlistStore.setlists) { setlist in
                Button {
                    setlistStore.toggle(item, in: setlist.id)
                } label: {
                    if setlistStore.contains(itemID: item.id, in: setlist.id) {
                        Label(setlist.name, systemImage: "checkmark")
                    } else {
                        Text(setlist.name)
                    }
                }
            }
            if !setlistStore.setlists.isEmpty {
                Divider()
            }
            Button {
                newName = ""
                showingNew = true
            } label: {
                Label("New Setlist…", systemImage: "plus")
            }
        } label: {
            Image(systemName: "music.note.list")
        }
        .alert("New Setlist", isPresented: $showingNew) {
            TextField("Name", text: $newName)
            Button("Create") {
                if let id = setlistStore.create(name: newName) {
                    setlistStore.add(item, to: id)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
