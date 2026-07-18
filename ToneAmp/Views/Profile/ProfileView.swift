import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(FavoritesStore.self) private var favorites
    @Environment(LibraryStore.self) private var library
    @Environment(RigStore.self) private var rigStore
    @Environment(AIToneCacheStore.self) private var aiCache

    @State private var myTones: [CommunityTone] = []
    @State private var isLoadingTones = false
    @State private var showingRigEditor = false
    @State private var showingSettings = false
    @State private var showingSignIn = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    HStack(spacing: 10) {
                        StatTile(
                            value: "\(favorites.songIDs.count)",
                            label: "Favorites",
                            symbol: "star.fill",
                            tint: .yellow
                        )
                        StatTile(
                            value: session.isSignedIn ? "\(myTones.count)" : "—",
                            label: "Published",
                            symbol: "paperplane.fill",
                            tint: .orange
                        )
                        StatTile(
                            value: "\(library.songs.count)",
                            label: "Songs",
                            symbol: "music.note",
                            tint: .indigo
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    if rigStore.rig.isConfigured {
                        let guitarList = ([rigStore.rig.guitarText] + rigStore.rig.guitars)
                            .filter { !$0.isEmpty }
                        if !guitarList.isEmpty {
                            LabeledContent {
                                Text(guitarList.joined(separator: ", "))
                                    .multilineTextAlignment(.trailing)
                            } label: {
                                Label("Guitars", systemImage: "guitars.fill")
                            }
                        }
                        let ampDisplay = rigStore.rig.ampText.isEmpty ? rigStore.rig.amp : rigStore.rig.ampText
                        if !ampDisplay.isEmpty {
                            LabeledContent {
                                Text(ampDisplay)
                                    .multilineTextAlignment(.trailing)
                            } label: {
                                Label("Amp", systemImage: "amplifier")
                            }
                        }
                        LabeledContent {
                            Text(
                                rigStore.rig.pedalsText.isEmpty
                                    ? "\(rigStore.rig.pedalTypes.count)"
                                    : rigStore.rig.pedalsText
                            )
                            .multilineTextAlignment(.trailing)
                        } label: {
                            Label("Pedals", systemImage: "bolt.fill")
                        }
                    }
                    Button {
                        showingRigEditor = true
                    } label: {
                        Label(
                            rigStore.rig.isConfigured ? "Edit My Rig" : "Set Up My Rig",
                            systemImage: "slider.horizontal.3"
                        )
                    }
                } header: {
                    Text("My Rig")
                } footer: {
                    Text("Tone pages use your rig to translate settings to your gear.")
                }

                if !aiCache.tones.isEmpty {
                    Section("My AI Tones") {
                        ForEach(aiCache.tones) { saved in
                            NavigationLink(value: saved) {
                                SavedAIToneRow(tone: saved)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                aiCache.delete(aiCache.tones[index])
                            }
                        }
                    }
                }

                if session.isSignedIn {
                    Section("My Published Tones") {
                        if isLoadingTones {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else if myTones.isEmpty {
                            Text("Nothing published yet — open any song in the Community tab and add your tone.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(myTones) { tone in
                                NavigationLink(value: tone) {
                                    CommunityToneRow(tone: tone)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationDestination(for: CommunityTone.self) { tone in
                CommunityToneDetailView(tone: tone)
            }
            .navigationDestination(for: SavedAITone.self) { saved in
                SavedAIToneDetailView(tone: saved)
            }
            .sheet(isPresented: $showingRigEditor) {
                MyRigView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingSignIn) {
                SignInSheet()
            }
            .task(id: session.userID) {
                await loadMyTones()
            }
            .refreshable {
                await loadMyTones()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 92, height: 92)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                if session.isSignedIn && !session.displayName.isEmpty {
                    Text(initials)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "guitars.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
            }
            VStack(spacing: 4) {
                Text(session.isSignedIn ? session.authorName : "Guest Guitarist")
                    .font(.title3.bold())
                HStack(spacing: 6) {
                    if session.isPro {
                        Text("PRO")
                            .font(.caption2.weight(.heavy))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Text(session.isSignedIn ? "Signed in with Apple" : "Browsing as guest")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !session.isSignedIn {
                Button {
                    showingSignIn = true
                } label: {
                    Label("Sign in with Apple", systemImage: "apple.logo")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private var initials: String {
        let parts = session.displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "T" : String(letters).uppercased()
    }

    @MainActor
    private func loadMyTones() async {
        guard let userID = session.userID else {
            myTones = []
            return
        }
        isLoadingTones = true
        if let tones = try? await CommunityService.tones(byAuthorID: userID) {
            myTones = tones
        }
        isLoadingTones = false
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.callout)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
