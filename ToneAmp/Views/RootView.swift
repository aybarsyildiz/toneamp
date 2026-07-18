import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if session.hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: session.hasOnboarded)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
            IdentifyView()
                .tabItem {
                    Label("Identify", systemImage: "shazam.logo.fill")
                }
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "star.fill")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}
