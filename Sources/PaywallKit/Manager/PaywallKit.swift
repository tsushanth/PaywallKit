import UIKit

// ─────────────────────────────────────────────────────────────────
//  INTEGRATION GUIDE  (2 steps per app, then resubmit)
//
//  STEP 1 — App launch (AppDelegate or SwiftUI App.init):
//
//      await PaywallKit.shared.configure(
//          appId:    "ClearVoice Recorder",   // must match app_name in offer_codes DB
//          appName:  "ClearVoice",             // display name
//          userId:   Auth.shared.userId,       // optional — falls back to device UUID
//          productIds: ["com.kreativekoala.clearvoice.subscription.monthly", ...]
//      )
//
//  STEP 2 — Root SwiftUI view:
//
//      ContentView()
//          .paywallKitReferral()
//
//  That's it. PaywallKit will:
//  • Automatically prompt existing subscribers to share after 4s (once per 30 days)
//  • Show "Give a Friend 7 Days Free" after every new purchase
//  • Track distribution in Supabase offer_codes
//
//  OPTIONAL — Settings screen button:
//      if ReferralManager.shared.isSubscribed {
//          Button("Give a Friend 7 Days Free") {
//              Task { await ReferralManager.shared.shareCode(from: hostVC) }
//          }
//      }
// ─────────────────────────────────────────────────────────────────

/// Global configuration for PaywallKit. Call `PaywallKit.configure(...)` once at app launch
/// (e.g. in `AppDelegate.didFinishLaunching` or the SwiftUI `App.init`).
///
/// After configure, PaywallKit will:
///  - Show referral prompts automatically to existing subscribers
///  - Wire userId into all paywall and referral flows without extra code
@available(iOS 16.0, *)
@MainActor
public final class PaywallKitSDK {

    // ── Singleton config ──
    public static let shared = PaywallKitSDK()
    private init() {}

    public private(set) var appId: String = ""
    public private(set) var appName: String = ""
    public private(set) var userId: String = ""

    private let referralShownKey = "pwkit_referral_last_shown"
    /// Minimum days between automatic referral prompts.
    public var referralPromptIntervalDays: Int = 30

    // ── Configure ──

    /// Call once at launch. Bootstraps all PaywallKit subsystems.
    ///
    /// - Parameters:
    ///   - appId: Matches the `app_name` stored in Supabase offer_codes (e.g. "ClearVoice Recorder").
    ///   - appName: Display name shown in UI (e.g. "ClearVoice").
    ///   - userId: Your app's user/device identifier. Used for referral attribution.
    ///   - productIds: StoreKit product IDs to load.
    ///   - showReferralToExistingSubscribers: If true, automatically shows a referral prompt
    ///     to already-subscribed users after a short delay (once per `referralPromptIntervalDays`).
    public func configure(
        appId: String,
        appName: String,
        userId: String? = nil,
        productIds: [String],
        showReferralToExistingSubscribers: Bool = true
    ) {
        self.appId = appId
        self.appName = appName
        self.userId = userId ?? ExperimentManager.shared.userId

        // Load StoreKit products
        StoreManager.shared.configure(productIds: productIds)

        // Schedule referral prompt for existing subscribers
        if showReferralToExistingSubscribers {
            Task {
                await scheduleReferralIfNeeded()
            }
        }

        // If a promo code was detected from a deep link / clipboard (before configure was called),
        // redeem it now that we have appId + userId.
        Task {
            await redeemDetectedPromoCodeIfNeeded()
        }
    }

    private func redeemDetectedPromoCodeIfNeeded() async {
        guard let code = PromoCodeManager.shared.activeCode,
              PromoCodeManager.shared.activeVariantId == nil   // not yet redeemed
        else { return }

        // Don't redeem if the user is already subscribed — offer code would be wasted
        guard !StoreManager.shared.isPremium else { return }

        await PaywallManager.shared.redeemPromoCode(code, appId: appId, userId: userId)
    }

    // ── Referral auto-prompt ──

    private func scheduleReferralIfNeeded() async {
        // Wait a moment for StoreKit to sync
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s

        guard StoreManager.shared.isPremium else { return }
        guard isReferralPromptDue() else { return }

        // Find the key window's root view controller
        guard let vc = rootViewController() else { return }

        await ReferralManager.shared.shareCode(
            appId: appId,
            userId: userId,
            appName: appName,
            from: vc
        )
        markReferralShown()
    }

    func isReferralPromptDue() -> Bool {
        let defaults = UserDefaults.standard
        guard let lastShown = defaults.object(forKey: referralShownKey) as? Date else { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: lastShown, to: Date()).day ?? 0
        return daysSince >= referralPromptIntervalDays
    }

    func markReferralShown() {
        UserDefaults.standard.set(Date(), forKey: referralShownKey)
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

/// Backward-compatible alias. Prefer PaywallKitSDK.shared.
@available(iOS 16.0, *) public typealias PaywallKitConfig = PaywallKitSDK
