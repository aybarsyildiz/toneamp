import SwiftUI

@main
struct ToneAmpApp: App {
    @State private var library = LibraryStore()
    @State private var favorites = FavoritesStore()
    @State private var session = SessionStore()
    @State private var rig = RigStore()
    @State private var aiTones = AIToneCacheStore()
    @State private var pro = ProStore()
    @State private var moderation = ModerationStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(favorites)
                .environment(session)
                .environment(rig)
                .environment(aiTones)
                .environment(pro)
                .environment(moderation)
                .task {
                    pro.onEntitlementChange = { active in
                        session.setPro(active)
                    }
                    pro.start()
                }
        }
    }
}
