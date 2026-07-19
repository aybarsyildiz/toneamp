import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(SessionStore.self) private var session
    @Environment(ProStore.self) private var pro
    @Environment(ModerationStore.self) private var moderation

    @State private var showingSignIn = false
    @State private var confirmingSignOut = false
    @State private var showingPaywall = false
    @State private var isRestoring = false

    private var privacyURL: URL {
        AIToneService.proxyURL?.appendingPathComponent("privacy")
            ?? URL(string: "https://github.com/aybarsyildiz/toneamp")!
    }

    private var supportURL: URL {
        AIToneService.proxyURL?.appendingPathComponent("support")
            ?? URL(string: "https://github.com/aybarsyildiz/toneamp")!
    }

    private var hiddenCount: Int {
        moderation.hiddenToneIDs.count + moderation.blockedAuthorIDs.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if session.isSignedIn {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.authorName)
                                    .font(.headline)
                                Text("Signed in with Apple")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("Sign Out", role: .destructive) {
                            confirmingSignOut = true
                        }
                    } else {
                        Button {
                            showingSignIn = true
                        } label: {
                            Label("Sign in with Apple", systemImage: "apple.logo")
                        }
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Browsing is always open. Favorites, publishing, rating, and the AI tone engine are tied to your account.")
                }

                Section {
                    LabeledContent {
                        Text(session.isPro ? "Active" : "Not subscribed")
                            .foregroundStyle(session.isPro ? .green : .secondary)
                    } label: {
                        Label("ToneAmp Pro", systemImage: "wand.and.stars")
                    }
                    #if DEBUG
                    Toggle(isOn: Binding(
                        get: { session.isPro },
                        set: { session.setPro($0) }
                    )) {
                        Label("Pro Override (debug)", systemImage: "ladybug")
                    }
                    #endif
                    if session.isPro {
                        Button {
                            openURL(URL(string: "https://apps.apple.com/account/subscriptions")!)
                        } label: {
                            Label("Manage Subscription", systemImage: "creditcard")
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            Label("See What Pro Unlocks", systemImage: "sparkles")
                        }
                    }
                    Button {
                        isRestoring = true
                        Task { @MainActor in
                            await pro.restore()
                            isRestoring = false
                        }
                    } label: {
                        if isRestoring {
                            HStack {
                                Label("Restoring…", systemImage: "arrow.clockwise")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRestoring)
                } header: {
                    Text("ToneAmp Pro")
                } footer: {
                    Text("Pro unlocks the AI tone engine — Identify Tones and Adapt to My Gear.")
                }

                Section {
                    Button {
                        moderation.unhideAll()
                    } label: {
                        Label(
                            hiddenCount == 0
                                ? "No Hidden Tones or Blocked Authors"
                                : "Restore Hidden & Blocked (\(hiddenCount))",
                            systemImage: "eye"
                        )
                    }
                    .disabled(hiddenCount == 0)
                } header: {
                    Text("Community")
                } footer: {
                    Text("Tones you've hidden and authors you've blocked come back after restoring.")
                }

                Section {
                    Button {
                        openURL(URL(string: "mailto:s.aybars.yildiz@gmail.com?subject=ToneAmp%20Feedback")!)
                    } label: {
                        Label("Contact & Feedback", systemImage: "envelope")
                    }
                    Button {
                        openURL(supportURL)
                    } label: {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                    Button {
                        openURL(privacyURL)
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Button {
                        openURL(URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    } label: {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                } header: {
                    Text("Help")
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                } header: {
                    Text("About")
                } footer: {
                    Text("Community tone settings are player-contributed starting points based on interviews, rig rundowns, and ears — dial in from there. Song data and artwork provided by Apple's iTunes catalog.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSignIn) {
                SignInSheet()
            }
            .fullScreenCover(isPresented: $showingPaywall) {
                ProPaywallView()
            }
            .confirmationDialog(
                "Sign out of ToneAmp?",
                isPresented: $confirmingSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    session.signOut()
                }
            } message: {
                Text("Your published tones stay in the community.")
            }
        }
    }
}
