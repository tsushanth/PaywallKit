import UIKit
import SwiftUI

/// Handles referral code distribution and presentation.
///
/// Primary entry points:
///  - `PaywallKit.configure(...)` — auto-prompts existing subscribers at launch
///  - `ReferralManager.shared.presentIfEligible(from:)` — call from settings or any screen
///  - `ReferralShareView` — embed directly in SwiftUI if you want manual placement
@available(iOS 16.0, *)
@MainActor
public final class ReferralManager {
    public static let shared = ReferralManager()
    private init() {}

    // MARK: - Present from UIKit (share sheet)

    /// Fetches a code and presents the iOS share sheet from `viewController`.
    /// Uses global PaywallKit config if appId/userId not provided.
    public func shareCode(
        appId: String? = nil,
        userId: String? = nil,
        appName: String? = nil,
        productId: String? = nil,
        from viewController: UIViewController
    ) async {
        let resolvedAppId   = appId   ?? PaywallKitSDK.shared.appId
        let resolvedUserId  = userId  ?? PaywallKitSDK.shared.userId
        let resolvedAppName = appName ?? PaywallKitSDK.shared.appName

        guard !resolvedAppId.isEmpty, !resolvedUserId.isEmpty else { return }

        guard let referral = await PaywallManager.shared.fetchReferralCode(
            appId: resolvedAppId, userId: resolvedUserId, productId: productId
        ) else { return }

        let message = "Try \(resolvedAppName) free for 7 days — my gift to you 🎁"
        let activity = UIActivityViewController(
            activityItems: [message, referral.redemptionURL],
            applicationActivities: nil
        )
        if let popover = activity.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        viewController.present(activity, animated: true)

        PaywallKitSDK.shared.markReferralShown()
    }

    // MARK: - Present SwiftUI sheet from UIKit

    /// Presents the full `ReferralShareView` sheet from a UIViewController.
    public func presentSheet(
        appId: String? = nil,
        userId: String? = nil,
        appName: String? = nil,
        productId: String? = nil,
        from viewController: UIViewController
    ) async {
        let resolvedAppId   = appId   ?? PaywallKitSDK.shared.appId
        let resolvedUserId  = userId  ?? PaywallKitSDK.shared.userId
        let resolvedAppName = appName ?? PaywallKitSDK.shared.appName

        guard !resolvedAppId.isEmpty, !resolvedUserId.isEmpty else { return }

        guard let referral = await PaywallManager.shared.fetchReferralCode(
            appId: resolvedAppId, userId: resolvedUserId, productId: productId
        ) else { return }

        let view = ReferralShareView(appName: resolvedAppName, redemptionURL: referral.redemptionURL) {
            viewController.dismiss(animated: true)
        }
        let host = UIHostingController(rootView: view)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        viewController.present(host, animated: true)

        PaywallKitSDK.shared.markReferralShown()
    }

    // MARK: - Eligibility check (for settings UI)

    /// Returns true if the user is subscribed and the referral prompt is due.
    /// Use this to show/hide a "Give a Friend 7 Days Free" button in settings.
    public var isEligible: Bool {
        StoreManager.shared.isPremium && PaywallKitSDK.shared.isReferralPromptDue()
    }

    /// Same as `isEligible` but ignores the interval — always true for subscribed users.
    public var isSubscribed: Bool {
        StoreManager.shared.isPremium
    }
}
