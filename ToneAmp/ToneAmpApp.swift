import SwiftUI

@main
struct ToneAmpApp: App {
    @State private var library = LibraryStore()
    @State private var favorites = FavoritesStore()
    @State private var session = SessionStore()
    @State private var rig = RigStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(favorites)
                .environment(session)
                .environment(rig)
        }
    }
}
