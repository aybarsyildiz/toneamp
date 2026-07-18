import AuthenticationServices
import SwiftUI

/// Animated onboarding: three feature pages, then Sign in with Apple.
struct OnboardingView: View {
    @Environment(SessionStore.self) private var session
    @Environment(RigStore.self) private var rigStore
    @State private var pageIndex = 0
    @State private var animateGradient = false

    /// 3 feature pages + rig page + sign-in page.
    private let signInPageIndex = 4

    private let pages: [OnboardPage] = [
        OnboardPage(
            symbol: "guitars.fill",
            title: "Find the Tone",
            subtitle: "Amp settings, pickups, and full pedalboards for the songs you love — knob by knob."
        ),
        OnboardPage(
            symbol: "shazam.logo.fill",
            title: "Hear It, Dial It",
            subtitle: "Identify any song that's playing and jump straight to its guitar tone."
        ),
        OnboardPage(
            symbol: "person.3.fill",
            title: "Built by Players",
            subtitle: "Publish your own tones for any song and rate the ones that nail it."
        ),
    ]

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if pageIndex < signInPageIndex {
                        Button("Skip") {
                            withAnimation(.spring(duration: 0.5)) {
                                pageIndex = signInPageIndex
                            }
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                    }
                }
                TabView(selection: $pageIndex) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardPageView(page: pages[index], isActive: pageIndex == index)
                            .tag(index)
                    }
                    rigPage
                        .tag(3)
                    signInPage
                        .tag(signInPageIndex)
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                if pageIndex < signInPageIndex {
                    Button {
                        withAnimation(.spring(duration: 0.5)) {
                            pageIndex += 1
                        }
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(.white, in: Capsule())
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: pageIndex)
    }

    private var background: some View {
        LinearGradient(
            colors: [Color.orange, Color(red: 0.85, green: 0.25, blue: 0.35), Color.indigo],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }

    private var rigPage: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: pageIndex == 3)
                    .padding(.top, 8)
                Text("What's Your Rig?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Every tone gets translated to your own gear. Pick what you play — refine anytime in Profile.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(alignment: .leading, spacing: 10) {
                    Text("GUITARS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                    onboardChips(GearCatalog.guitars, isSelected: { rigStore.rig.guitars.contains($0) }) { guitar in
                        if let index = rigStore.rig.guitars.firstIndex(of: guitar) {
                            rigStore.rig.guitars.remove(at: index)
                        } else {
                            rigStore.rig.guitars.append(guitar)
                        }
                    }
                    Text("AMP")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 6)
                    onboardChips(GearCatalog.amps, isSelected: { rigStore.rig.amp == $0 }) { amp in
                        rigStore.rig.amp = rigStore.rig.amp == amp ? "" : amp
                    }
                    Text("OR TYPE YOUR EXACT GEAR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 6)
                    onboardTextField("Guitar — e.g. Player Strat HSS", text: guitarTextBinding)
                    onboardTextField("Amp — e.g. Boss Katana 50 MkII", text: ampTextBinding)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }

    private var guitarTextBinding: Binding<String> {
        Binding(
            get: { rigStore.rig.guitarText },
            set: { rigStore.rig.guitarText = $0 }
        )
    }

    private var ampTextBinding: Binding<String> {
        Binding(
            get: { rigStore.rig.ampText },
            set: { rigStore.rig.ampText = $0 }
        )
    }

    private func onboardTextField(_ prompt: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.55)))
            .foregroundStyle(.white)
            .tint(.white)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func onboardChips(
        _ items: [String],
        isSelected: @escaping (String) -> Bool,
        toggle: @escaping (String) -> Void
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    withAnimation(.snappy) {
                        toggle(item)
                    }
                } label: {
                    Text(item)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected(item) ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.18)),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected(item) ? .black : .white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var signInPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "amplifier")
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: pageIndex == pages.count)
            Text("Join the Community")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("Sign in to publish tones and rate what other players share. You can browse everything without an account.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                handleSignIn(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .padding(.horizontal, 28)
            Button("Maybe Later") {
                session.completeOnboarding()
            }
            .foregroundStyle(.white.opacity(0.8))
            .padding(.bottom, 40)
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
            // User cancelled — stay on the page.
            break
        }
    }
}

private struct OnboardPage {
    let symbol: String
    let title: String
    let subtitle: String
}

private struct OnboardPageView: View {
    let page: OnboardPage
    let isActive: Bool

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: page.symbol)
                .font(.system(size: 88))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: isActive)
                .scaleEffect(isActive ? 1 : 0.7)
                .animation(.spring(duration: 0.6, bounce: 0.4), value: isActive)
            Text(page.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(page.subtitle)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
            Spacer()
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
