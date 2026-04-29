import StoreKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// StoreKit 2 purchase manager built into PaywallKit.
/// Replaces RevenueCat — handles product loading, purchases, subscription status.
///
/// Usage:
/// ```swift
/// // At app startup:
/// StoreManager.shared.configure(productIds: [
///     "com.myapp.weekly",
///     "com.myapp.monthly",
///     "com.myapp.yearly"
/// ])
///
/// // Check subscription:
/// let isPremium = await StoreManager.shared.isPremium
///
/// // Products are auto-loaded and available as PaywallProduct:
/// let products = StoreManager.shared.paywallProducts
/// ```
@MainActor
public final class StoreManager: ObservableObject {
    public static let shared = StoreManager()

    // MARK: - Published State

    @Published public private(set) var paywallProducts: [PaywallProduct] = []
    @Published public private(set) var isPremium: Bool = false
    @Published public private(set) var subscriptionExpirationDate: Date?
    @Published public private(set) var isLifetime: Bool = false

    // MARK: - Purchase Callback

    /// Called when a purchase completes successfully. Register your analytics hook here.
    /// Parameters: (productId: String, price: Decimal?, currencyCode: String?)
    public var onPurchaseCompleted: ((String, Decimal?, String?) -> Void)?

    // MARK: - Offer After Dismiss

    /// When true, PaywallKit auto-presents Apple's offer code redemption sheet
    /// after the user dismisses a paywall (on the Nth dismissal).
    /// Defaults to true. Set to false to disable.
    public var offerAfterDismissEnabled: Bool = true

    /// Number of paywall dismissals before showing the Apple offer sheet.
    /// Default: 1 (show on first dismiss). Set higher to wait.
    public var offerAfterDismissThreshold: Int = 1

    /// Minimum seconds between offer presentations. Default: 86400 (1 day).
    public var offerAfterDismissCooldown: TimeInterval = 86_400

    /// Tracks a paywall dismiss and optionally presents Apple's offer code sheet.
    /// Call this from your paywall's onDismiss callback.
    public func trackPaywallDismiss() {
        guard offerAfterDismissEnabled, !isPremium else { return }

        let count = defaults.integer(forKey: DismissKeys.count) + 1
        defaults.set(count, forKey: DismissKeys.count)
        defaults.set(Date().timeIntervalSince1970, forKey: DismissKeys.lastDismiss)

        print("[PaywallKit/StoreManager] Paywall dismiss #\(count)")

        guard count >= offerAfterDismissThreshold else { return }

        // Check cooldown
        let lastOffer = defaults.double(forKey: DismissKeys.lastOffer)
        if lastOffer > 0 && Date().timeIntervalSince1970 - lastOffer < offerAfterDismissCooldown {
            return
        }

        // Present Apple's offer code redemption sheet
        defaults.set(Date().timeIntervalSince1970, forKey: DismissKeys.lastOffer)
        defaults.set(0, forKey: DismissKeys.count) // reset count

        #if canImport(UIKit) && !os(watchOS)
        Task { @MainActor in
            // Small delay so the paywall sheet fully dismisses first
            try? await Task.sleep(nanoseconds: 800_000_000)
            if #available(iOS 16.0, *) {
                if let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) {
                    try? await AppStore.presentOfferCodeRedeemSheet(in: scene)
                    print("[PaywallKit/StoreManager] Offer code redeem sheet presented")
                }
            } else {
                SKPaymentQueue.default().presentCodeRedemptionSheet()
                print("[PaywallKit/StoreManager] Legacy offer code sheet presented")
            }
        }
        #endif
    }

    // MARK: - Internal

    private var storeProducts: [Product] = []
    private var productIds: Set<String> = []
    private var transactionListener: Task<Void, Error>?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isPremium = "pwkit_is_premium"
        static let expirationDate = "pwkit_expiration"
        static let isLifetime = "pwkit_is_lifetime"
    }

    private enum DismissKeys {
        static let count = "pwkit_dismiss_count"
        static let lastDismiss = "pwkit_last_dismiss"
        static let lastOffer = "pwkit_last_offer_shown"
    }

    private init() {
        // Load persisted state for instant access before async validation
        isPremium = defaults.bool(forKey: Keys.isPremium)
        isLifetime = defaults.bool(forKey: Keys.isLifetime)
        if let interval = defaults.object(forKey: Keys.expirationDate) as? TimeInterval {
            subscriptionExpirationDate = Date(timeIntervalSince1970: interval)
        }
    }

    // MARK: - Configuration

    /// Call at app startup with your product identifiers.
    public func configure(productIds: [String]) {
        self.productIds = Set(productIds)
        startTransactionListener()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
        }
    }

    // MARK: - Product Loading

    /// Loads products from App Store and converts to PaywallProduct.
    public func loadProducts() async {
        do {
            print("[PaywallKit/StoreManager] Loading products for IDs: \(productIds)")
            storeProducts = try await Product.products(for: productIds)
            paywallProducts = storeProducts.compactMap { convert($0) }
                .sorted { periodOrder($0.period) < periodOrder($1.period) }
            print("[PaywallKit/StoreManager] Loaded \(paywallProducts.count) products: \(paywallProducts.map { "\($0.id) \($0.localizedPrice)" })")
        } catch {
            print("[PaywallKit/StoreManager] Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    /// Purchase a product by its ID.
    @discardableResult
    public func purchase(productId: String) async -> PurchaseResult {
        print("[PaywallKit/StoreManager] Purchase requested: \(productId)")
        guard let product = storeProducts.first(where: { $0.id == productId }) else {
            print("[PaywallKit/StoreManager] Product not found! Available: \(storeProducts.map { $0.id })")
            return .failed(StoreError.productNotFound)
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerification(verification)
                await transaction.finish()
                await refreshSubscriptionStatus()
                onPurchaseCompleted?(productId, product.price, product.priceFormatStyle.currencyCode)
                return .purchased

            case .pending:
                return .pending

            case .userCancelled:
                return .cancelled

            @unknown default:
                return .failed(StoreError.unknown)
            }
        } catch {
            return .failed(error)
        }
    }

    /// Purchase a product with a promotional offer option (win-back flow).
    /// The offer is signed server-side via `PromoOfferSigner`. Falls back to a standard
    /// purchase if signing fails.
    @discardableResult
    @available(iOS 15.0, macOS 12.0, *)
    public func purchaseWithPromoOffer(productId: String, offerCode: String) async -> PurchaseResult {
        guard let product = storeProducts.first(where: { $0.id == productId }) else {
            return .failed(StoreError.productNotFound)
        }
        let options: Set<Product.PurchaseOption>
        if let option = try? await PromoOfferSigner.purchaseOption(product: product, offerCode: offerCode) {
            options = [option]
        } else {
            options = []
        }
        do {
            let result = try await product.purchase(options: options)
            switch result {
            case .success(let verification):
                let transaction = try checkVerification(verification)
                await transaction.finish()
                await refreshSubscriptionStatus()
                onPurchaseCompleted?(productId, product.price, product.priceFormatStyle.currencyCode)
                return .purchased
            case .pending: return .pending
            case .userCancelled: return .cancelled
            @unknown default: return .failed(StoreError.unknown)
            }
        } catch {
            return .failed(error)
        }
    }

    // MARK: - Restore

    /// Syncs with App Store to restore previous purchases.
    public func restore() async {
        try? await AppStore.sync()
        await refreshSubscriptionStatus()
    }

    // MARK: - Subscription Status

    /// Refreshes subscription status from StoreKit 2's verified transactions.
    public func refreshSubscriptionStatus() async {
        var foundActive = false
        var latestExpiration: Date?
        var foundLifetime = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerification(result) else { continue }

            switch transaction.productType {
            case .autoRenewable:
                foundActive = true
                if let exp = transaction.expirationDate {
                    if latestExpiration == nil || exp > latestExpiration! {
                        latestExpiration = exp
                    }
                }
            case .nonRenewable, .nonConsumable:
                // Lifetime / one-time purchase
                foundActive = true
                foundLifetime = true
            default:
                break
            }
        }

        isPremium = foundActive
        subscriptionExpirationDate = latestExpiration
        isLifetime = foundLifetime
        persistState()
    }

    /// Days remaining on subscription (nil if lifetime or not subscribed).
    public var remainingDays: Int? {
        guard isPremium, !isLifetime, let exp = subscriptionExpirationDate else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0)
    }

    // MARK: - Transaction Listener

    private var messageListener: Task<Void, Never>?

    private func startTransactionListener() {
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if let transaction = try? await self.checkVerification(result) {
                    await transaction.finish()
                }
                await MainActor.run {
                    Task { await self.refreshSubscriptionStatus() }
                }
            }
        }
        startMessageListener()
    }

    /// Listen for StoreKit messages (win-back offers, price increases, offer codes).
    /// Apple sends these automatically — we just need to display them.
    private func startMessageListener() {
        #if canImport(UIKit) && !os(watchOS)
        messageListener = Task.detached { @MainActor in
            for await message in StoreKit.Message.messages {
                print("[PaywallKit/StoreManager] Received StoreKit message: \(message.reason)")
                if let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }) {
                    do {
                        try await message.display(in: scene)
                        print("[PaywallKit/StoreManager] StoreKit message displayed")
                    } catch {
                        print("[PaywallKit/StoreManager] Failed to display message: \(error)")
                    }
                }
            }
        }
        #endif
    }

    // MARK: - Helpers

    private func checkVerification<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified(_, let error):
            throw error
        }
    }

    private func convert(_ product: Product) -> PaywallProduct? {
        let period: PaywallProduct.Period
        if let sub = product.subscription {
            switch sub.subscriptionPeriod.unit {
            case .day:
                period = sub.subscriptionPeriod.value == 7 ? .weekly : .weekly
            case .week:
                period = .weekly
            case .month:
                period = sub.subscriptionPeriod.value >= 12 ? .yearly : .monthly
            case .year:
                period = .yearly
            @unknown default:
                return nil
            }
        } else {
            period = .lifetime
        }

        var trialDays: Int?
        if let intro = product.subscription?.introductoryOffer,
           intro.paymentMode == .freeTrial {
            let p = intro.period
            switch p.unit {
            case .day: trialDays = p.value
            case .week: trialDays = p.value * 7
            case .month: trialDays = p.value * 30
            case .year: trialDays = p.value * 365
            @unknown default: trialDays = p.value
            }
        }

        return PaywallProduct(
            id: product.id,
            localizedPrice: product.displayPrice,
            price: product.price,
            currencyCode: product.priceFormatStyle.currencyCode,
            trialDays: trialDays,
            period: period
        )
    }

    private func periodOrder(_ period: PaywallProduct.Period) -> Int {
        switch period {
        case .yearly: return 0
        case .monthly: return 1
        case .weekly: return 2
        case .lifetime: return 3
        }
    }

    private func persistState() {
        defaults.set(isPremium, forKey: Keys.isPremium)
        defaults.set(isLifetime, forKey: Keys.isLifetime)
        if let exp = subscriptionExpirationDate {
            defaults.set(exp.timeIntervalSince1970, forKey: Keys.expirationDate)
        } else {
            defaults.removeObject(forKey: Keys.expirationDate)
        }
    }

    // MARK: - Types

    public enum PurchaseResult {
        case purchased
        case pending
        case cancelled
        case failed(Error)
    }

    public enum StoreError: LocalizedError {
        case productNotFound
        case unknown

        public var errorDescription: String? {
            switch self {
            case .productNotFound: return "Product not found"
            case .unknown: return "An unknown error occurred"
            }
        }
    }
}
