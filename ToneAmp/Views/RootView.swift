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
    @State private var selectedTab = 0

    var body: some View {
        @Bindable var session = session
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
                .tag(0)
            CommunityView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
                .tag(1)
            IdentifyView()
                .tabItem {
                    Label("Identify", systemImage: "shazam.logo.fill")
                }
                .tag(2)
            MyRigView(showsDone: false)
                .tabItem {
                    Label("My Rig", systemImage: "guitars.fill")
                }
                .tag(3)
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
                .tag(4)
        }
        // toneamp://contest — App Store event cards land on the weekly contest.
        .onOpenURL { url in
            switch url.host() {
            case "contest", "community":
                selectedTab = 1
            case "identify":
                selectedTab = 2
            default:
                break
            }
        }
        .sheet(isPresented: $session.showingSignInGate) {
            SignInSheet()
        }
    }
}
