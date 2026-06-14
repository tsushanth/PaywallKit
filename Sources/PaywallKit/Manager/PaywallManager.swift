import Foundation
import UIKit

/// Handles event tracking to the PaywallKit API.
@MainActor
public final class PaywallManager {
    public static let shared = PaywallManager()

    let apiBase: String

    private init() {
        let info = Bundle.main.infoDictionary
        self.apiBase = info?["PaywallKitAPIBase"] as? String
            ?? "https://paywallkit-api.fly.dev"
    }

    // MARK: - Event Tracking

    /// Tracks a paywall event. Fire-and-forget.
    public func trackEvent(
        appId: String,
        placement: String,
        templateId: String,
        event: String,
        productId: String? = nil,
        email: String? = nil,
        revenueUsd: Double? = nil,
        promoCode: String? = nil
    ) {
        guard let url = URL(string: "\(apiBase)/event") else { return }

        var body: [String: Any] = [
            "app": appId,
            "placement": placement,
            "variant": templateId,
            "userId": ExperimentManager.shared.userId,
            "event": event,
        ]
        if let productId { body["productId"] = productId }
        // Normalize email: lowercase + trim before sending
        if let email { body["email"] = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        if let revenueUsd { body["revenue_usd"] = revenueUsd }
        // Attach promo code so the server can attribute conversion to the campaign
        let code = promoCode ?? PromoCodeManager.shared.activeCode
        if let code { body["promo_code"] = code }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        Task.detached(priority: .utility) {
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    // MARK: - Promo Code Redemption

    public struct PromoRedemptionResult {
        public let redemptionURL: URL
        public let ascCode: String
        public let offerHeadline: String
        public let paywallkitVariantId: String?
        public let campaignId: String
    }

    /// Redeems a marketing promo code (e.g. "FOCUS30") against the server inventory.
    /// Returns a result with the Apple redemption URL to open and the PaywallKit
    /// variant ID to show on the custom welcome paywall.
    ///
    /// After a successful redemption, automatically opens the Apple redemption URL
    /// and stores the variant ID so subsequent paywall resolves pick it up.
    @discardableResult
    public func redeemPromoCode(_ code: String, appId: String, userId: String) async -> PromoRedemptionResult? {
        guard let url = URL(string: "\(apiBase)/redeem-promo") else { return nil }

        let body: [String: Any] = ["promoCode": code, "appId": appId, "userId": userId]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              let status = (resp as? HTTPURLResponse)?.statusCode,
              (200..<300).contains(status),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlString = json["redemptionUrl"] as? String,
              let redemptionURL = URL(string: urlString),
              let ascCode = json["ascCode"] as? String,
              let campaignId = json["campaignId"] as? String
        else { return nil }

        let result = PromoRedemptionResult(
            redemptionURL: redemptionURL,
            ascCode: ascCode,
            offerHeadline: json["offerHeadline"] as? String ?? "",
            paywallkitVariantId: json["paywallkitVariantId"] as? String,
            campaignId: campaignId
        )

        // Persist so paywall templates and event tracking can reference it
        PromoCodeManager.shared.store(code: code, variantId: result.paywallkitVariantId)

        await MainActor.run {
            UIApplication.shared.open(redemptionURL)
        }

        return result
    }

    // Legal URLs — set globally, used by all templates
    public var termsURL: URL? = URL(string: "https://kreativekoala.llc/terms")
    public var privacyURL: URL? = URL(string: "https://kreativekoala.llc/privacy")

    // Legacy analytics handler (for Firebase/Mixpanel)
    public var analyticsHandler: ((_ event: String, _ params: [String: String]) -> Void)?

    // MARK: - Referral

    public struct ReferralCode {
        public let code: String
        public let redemptionURL: URL
        public let appName: String
        public let productId: String
    }

    /// Fetches a one-time-use offer code to give to a friend.
    /// Returns nil if no codes are available.
    public func fetchReferralCode(appId: String, userId: String, productId: String? = nil) async -> ReferralCode? {
        guard let url = URL(string: "\(apiBase)/referral/code") else { return nil }

        var body: [String: Any] = ["appId": appId, "userId": userId]
        if let productId { body["productId"] = productId }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? String,
              let urlString = json["redemptionUrl"] as? String,
              let redemptionURL = URL(string: urlString) else { return nil }

        return ReferralCode(
            code: code,
            redemptionURL: redemptionURL,
            appName: json["appName"] as? String ?? appId,
            productId: json["productId"] as? String ?? ""
        )
    }
}
