import AuthenticationServices
import SwiftUI

/// Clean, system-native onboarding: welcome → what it does → add your gear
/// (search-first) → sign in. No gradients, standard components, real haptics.
struct OnboardingView: View {
    @Environment(SessionStore.self) private var session
    @Environment(RigStore.self) private var rigStore
    @State private var page = 0

    private let lastPage = 6

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                featuresPage.tag(1)
                gearPage(
                    category: .guitar,
                    title: "Your Guitar",
                    subtitle: "Search and tap — one or several.",
                    pageIndex: 2
                )
                .tag(2)
                gearPage(
                    category: .amp,
                    title: "Your Amp",
                    subtitle: "No amp? Pick \u{201C}Audio interface (direct to PC)\u{201D}.",
                    pageIndex: 3
                )
                .tag(3)
                gearPage(
                    category: .multiFX,
                    title: "Multi-FX or Modeler",
                    subtitle: "GT, Helix, Kemper… it covers every effect at once.",
                    pageIndex: 4
                )
                .tag(4)
                gearPage(
                    category: .pedal,
                    title: "Your Pedals",
                    subtitle: "Individual pedals, if you run any.",
                    pageIndex: 5
                )
                .tag(5)
                signInPage.tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 14) {
                pageDots
                if page < lastPage {
                    Button {
                        withAnimation(.snappy) {
                            page += 1
                        }
                    } label: {
                        Text(continueLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 18)
        }
        .background(Color(.systemBackground))
        .sensoryFeedback(.selection, trigger: page)
    }

    /// Gear pages say "Skip" until something in that category is picked.
    private var continueLabel: String {
        let category: GearItem.Category?
        switch page {
        case 2: category = .guitar
        case 3: category = .amp
        case 4: category = .multiFX
        case 5: category = .pedal
        default: category = nil
        }
        guard let category else { return "Continue" }
        return hasContent(for: category) ? "Continue" : "Skip"
    }

    private func hasContent(for category: GearItem.Category) -> Bool {
        if rigStore.selectedGearItems.contains(where: { $0.category == category }) {
            return true
        }
        switch category {
        case .guitar:
            return !rigStore.rig.guitarText.isEmpty || !rigStore.rig.guitars.isEmpty
        case .amp:
            return !rigStore.rig.ampText.isEmpty || !rigStore.rig.amp.isEmpty
        case .multiFX, .pedal:
            return !rigStore.rig.pedalsText.isEmpty || !rigStore.rig.pedalTypes.isEmpty
        }
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0...lastPage, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.accentColor : Color(.systemFill))
                    .frame(width: index == page ? 22 : 7, height: 7)
                    .animation(.snappy, value: page)
            }
        }
    }

    // MARK: Pages

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 130, height: 130)
                Image(systemName: "amplifier")
                    .font(.system(size: 58))
                    .foregroundStyle(.tint)
                    .symbolEffect(.bounce, value: page == 0)
            }
            Text("Welcome to ToneAmp")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Hear a guitar tone you love?\nToneAmp tells you how to dial it in.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    private var featuresPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Text("Everything for the Tone")
                .font(.largeTitle.bold())
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
            VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    symbol: "music.note.list",
                    tint: .orange,
                    title: "1,300+ songs, knob by knob",
                    text: "Amp settings, pickups, and full pedalboards — including Turkish rock."
                )
                FeatureRow(
                    symbol: "shazam.logo.fill",
                    tint: .blue,
                    title: "Identify what's playing",
                    text: "One tap recognizes the song and jumps to its tone."
                )
                FeatureRow(
                    symbol: "person.3.fill",
                    tint: .green,
                    title: "By players, for players",
                    text: "Publish your own tones and rate the ones that nail it."
                )
                FeatureRow(
                    symbol: "wand.and.stars",
                    tint: .purple,
                    title: "Adapt any tone to your gear",
                    text: "Pro translates settings to your exact amp and pedals."
                )
            }
            .padding(.horizontal, 28)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gearPage(
        category: GearItem.Category,
        title: String,
        subtitle: String,
        pageIndex: Int
    ) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: category.symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .symbolEffect(.bounce, value: page == pageIndex)
                Text(title)
                    .font(.title.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 18)
            .padding(.bottom, 12)
            GearPickerView(fixedCategory: category)
        }
    }

    private var signInPage: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .symbolEffect(.bounce, value: page == lastPage)
            }
            Text("Join the Community")
                .font(.largeTitle.bold())
            Text("Sign in to publish and rate tones.\nBrowsing never needs an account.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                handleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .padding(.horizontal, 24)
            Button("Continue as Guest") {
                session.completeOnboarding()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
        }
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let name = [
                    credential.fullName?.givenName,
                    credential.fullName?.familyName,
                ]
                .compactMap { $0 }
                .joined(separator: " ")
                session.completeSignIn(userID: credential.user, displayName: name)
            }
            session.completeOnboarding()
        case .failure:
            break
        }
    }
}

private struct FeatureRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Reusable Sign in with Apple sheet, shown when a guest tries to publish
/// or rate.
struct SignInSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 40)
            Text("Sign In to Continue")
                .font(.title2.bold())
            Text("Publishing and rating tones needs an account, so every tone has a real author behind it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                if case .success(let authorization) = result,
                   let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    let name = [
                        credential.fullName?.givenName,
                        credential.fullName?.familyName,
                    ]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    session.completeSignIn(userID: credential.user, displayName: name)
                    dismiss()
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .padding(.horizontal, 28)
            Button("Not Now") {
                dismiss()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
        }
        .presentationDetents([.medium])
    }
}
