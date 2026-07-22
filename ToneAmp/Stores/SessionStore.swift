import Foundation
import Observation

/// Onboarding + Sign in with Apple session state. The stable Apple user ID
/// lives in the Keychain; presentation state in UserDefaults.
@Observable
final class SessionStore {
    private static let onboardedKey = "toneamp.hasOnboarded"
    private static let displayNameKey = "toneamp.displayName"
    private static let proKey = "toneamp.isPro"

    private(set) var hasOnboarded: Bool
    private(set) var userID: String?
    private(set) var displayName: String
    /// Pro entitlement. Preview flag until StoreKit lands with monetization.
    private(set) var isPro: Bool

    init() {
        hasOnboarded = UserDefaults.standard.bool(forKey: Self.onboardedKey)
        userID = KeychainStore.read(forKey: KeychainStore.appleUserIDAccount)
        displayName = UserDefaults.standard.string(forKey: Self.displayNameKey) ?? ""
        isPro = UserDefaults.standard.bool(forKey: Self.proKey)
    }

    func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: Self.proKey)
    }

    var isSignedIn: Bool {
        userID != nil
    }

    /// Presents the app-wide sign-in sheet (attached in RootView).
    var showingSignInGate = false

    /// Soft gate for interactive actions: browsing is open, acting needs an
    /// account. Returns true when signed in; otherwise presents the sign-in
    /// sheet and returns false so the caller can bail.
    func requireSignIn() -> Bool {
        if isSignedIn {
            return true
        }
        showingSignInGate = true
        return false
    }

    var authorName: String {
        displayName.isEmpty ? "Guitarist" : displayName
    }

    func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: Self.onboardedKey)
    }

    func replayOnboarding() {
        hasOnboarded = false
        UserDefaults.standard.set(false, forKey: Self.onboardedKey)
    }

    /// App Review demo mode (Guideline 2.1a): unlocks a full-featured local
    /// account including Pro, no Apple ID or purchase needed. Entered via
    /// the access code on the sign-in sheet; the code lives in App Store
    /// Connect's review notes.
    func startReviewDemo() {
        completeSignIn(userID: "demo-app-review", displayName: "App Reviewer")
        setPro(true)
    }

    func completeSignIn(userID: String, displayName: String) {
        self.userID = userID
        KeychainStore.save(userID, forKey: KeychainStore.appleUserIDAccount)
        // Apple only provides the name on first authorization, and a name
        // the user typed themselves always wins over the credential's.
        if !displayName.isEmpty && self.displayName.isEmpty {
            self.displayName = displayName
            UserDefaults.standard.set(displayName, forKey: Self.displayNameKey)
        }
    }

    /// User-chosen display name — editable any time, like the avatar.
    func setDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.displayNameKey)
    }

    func signOut() {
        userID = nil
        KeychainStore.delete(forKey: KeychainStore.appleUserIDAccount)
    }
}
