import Foundation
import Observation
import StoreKit

/// Real subscriptions via StoreKit 2. The product IDs below must be created
/// in App Store Connect (Monetization → Subscriptions) before the paywall
/// can sell; until products load, the paywall shows fallback prices.
@Observable
final class ProStore {
    // "pro.yearly" is dead — its ASC record corrupted pre-launch and was
    // replaced by "pro.annual" (same price, same trial). Never reuse the old ID.
    static let yearlyID = "com.netnucleus.toneamp.pro.annual"
    static let monthlyID = "com.netnucleus.toneamp.pro.monthly"
    static let allProductIDs = [yearlyID, monthlyID]

    private(set) var products: [Product] = []
    private(set) var hasEntitlement = false
    private(set) var isPurchasing = false
    var lastError: String?

    /// Fires on every App Store entitlement change (purchase, renewal,
    /// refund) — wired to SessionStore.setPro at app startup.
    var onEntitlementChange: ((Bool) -> Void)?

    private var updatesTask: Task<Void, Never>?
    private static let purchasedFlagKey = "toneamp.proFromStoreKit"

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlement()
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    @MainActor
    func loadProducts() async {
        guard products.isEmpty else { return }
        do {
            let loaded = try await Product.products(for: Self.allProductIDs)
            // Keep display order stable: yearly first.
            products = Self.allProductIDs.compactMap { id in
                loaded.first { $0.id == id }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func purchase(productID: String) async {
        guard let product = product(for: productID) else {
            lastError = "Subscriptions aren't available right now — check your connection and try again."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlement()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }

    @MainActor
    func refreshEntitlement() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               Self.allProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                active = true
            }
        }
        // Pro is only ever revoked here if StoreKit granted it — the
        // DEBUG preview toggle is never clobbered by an entitlement sweep.
        let defaults = UserDefaults.standard
        if active {
            defaults.set(true, forKey: Self.purchasedFlagKey)
            hasEntitlement = true
            onEntitlementChange?(true)
        } else if defaults.bool(forKey: Self.purchasedFlagKey) {
            defaults.set(false, forKey: Self.purchasedFlagKey)
            hasEntitlement = false
            onEntitlementChange?(false)
        } else {
            hasEntitlement = false
        }
    }
}
