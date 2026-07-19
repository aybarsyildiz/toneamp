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

    func completeSignIn(userID: String, displayName: String) {
        self.userID = userID
        KeychainStore.save(userID, forKey: KeychainStore.appleUserIDAccount)
        // Apple only provides the name on first authorization — keep any
        // previously stored name when the credential comes back empty.
        if !displayName.isEmpty {
            self.displayName = displayName
            UserDefaults.standard.set(displayName, forKey: Self.displayNameKey)
        }
    }

    func signOut() {
        userID = nil
        KeychainStore.delete(forKey: KeychainStore.appleUserIDAccount)
    }
}
