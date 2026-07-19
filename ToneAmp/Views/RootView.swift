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
    @Environment(SessionStore.self) private var session

    var body: some View {
        @Bindable var session = session
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
            MyRigView(showsDone: false)
                .tabItem {
                    Label("My Rig", systemImage: "guitars.fill")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .sheet(isPresented: $session.showingSignInGate) {
            SignInSheet()
        }
    }
}
