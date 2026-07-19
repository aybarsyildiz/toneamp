import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session

    @State private var showingSignIn = false
    @State private var confirmingSignOut = false
    @State private var apiKeyInput = ""
    @State private var hasStoredKey =
        KeychainStore.read(forKey: KeychainStore.anthropicAPIKeyAccount)?.isEmpty == false

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
                    Text("An account is needed to publish and rate tones. Browsing is always open.")
                }

                Section {
                    LabeledContent {
                        Text(session.isPro ? "Active" : "Not subscribed")
                            .foregroundStyle(session.isPro ? .green : .secondary)
                    } label: {
                        Label("ToneAmp Pro", systemImage: "wand.and.stars")
                    }
                    if session.isPro {
                        if hasStoredKey {
                            HStack {
                                Label("Tone engine key saved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    KeychainStore.delete(forKey: KeychainStore.anthropicAPIKeyAccount)
                                    hasStoredKey = false
                                }
                                .font(.subheadline)
                            }
                        } else if AIToneService.bundledAPIKey != nil {
                            Label("Development key bundled (Secrets.plist)", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else {
                            SecureField("Anthropic API key (sk-ant-…)", text: $apiKeyInput)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button("Save Key") {
                                let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                KeychainStore.save(trimmed, forKey: KeychainStore.anthropicAPIKeyAccount)
                                apiKeyInput = ""
                                hasStoredKey = true
                            }
                            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                } header: {
                    Text("ToneAmp Pro")
                } footer: {
                    Text("Pro unlocks the AI tone engine — Identify Tones and Adapt to My Gear. Manage or cancel your subscription in the Settings app → your Apple ID → Subscriptions.")
                }

                Section {
                    LabeledContent("Version", value: "1.0")
                    Button {
                        dismiss()
                        session.replayOnboarding()
                    } label: {
                        Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
                    }
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
