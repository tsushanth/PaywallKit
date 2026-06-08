import Foundation
import SwiftUI
import StoreKit

/// Server config for the offer-code prompt shown after paywall dismissal.
public struct OfferCodeConfig: Codable, Equatable {
    public let enabled: Bool
    public let code: String?
    public let title: String?
    public let description: String?
    public let discountText: String?
    public let appleAppId: String?

    public static let disabled = OfferCodeConfig(
        enabled: false,
        code: nil,
        title: nil,
        description: nil,
        discountText: nil,
        appleAppId: nil
    )
}

/// Fetches the per-app offer-code config from PaywallKit-API and presents the
/// redemption deep link. Off by default; flip on via `/admin/offer-config`.
@MainActor
public final class OfferCodeManager: ObservableObject {
    public static let shared = OfferCodeManager()

    @Published public var config: OfferCodeConfig = .disabled
    @Published public var isShowingOfferSheet = false

    private let apiBase: String
    private var lastFetch: Date?
    private let refreshInterval: TimeInterval = 300

    private init() {
        let info = Bundle.main.infoDictionary
        self.apiBase = info?["PaywallKitAPIBase"] as? String
            ?? "https://paywallkit-api.fly.dev"
    }

    /// Fetch latest config. Call once on app launch and again before showing the offer.
    public func refresh(appId: String) async {
        if let last = lastFetch, Date().timeIntervalSince(last) < refreshInterval { return }
        guard var components = URLComponents(string: "\(apiBase)/offer-config") else { return }
        components.queryItems = [URLQueryItem(name: "appId", value: appId)]
        guard let url = components.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OfferCodeConfig.self, from: data)
            self.config = decoded
            self.lastFetch = Date()
        } catch {
            // Silent fail — keeps the .disabled default.
        }
    }

    /// Should we show the offer sheet right now?
    public func shouldShow() -> Bool {
        guard config.enabled else { return false }
        guard let code = config.code, !code.isEmpty else { return false }
        return true
    }

    /// Present the empty StoreKit redemption sheet so the user can enter any code.
    /// Use this from a Settings "Redeem Promo Code" button.
    public func presentRedemptionSheet() {
        Task { try? await AppStore.presentOfferCodeRedeemSheet(in: keyWindowScene()) }
    }

    /// Redeem via the App Store deep link with the code pre-filled.
    public func redeem() {
        guard let code = config.code, !code.isEmpty else { return }
        guard let appleId = config.appleAppId, !appleId.isEmpty else {
            // Fall back to in-app sheet if we don't have an Apple ID.
            UIPasteboard.general.string = code
            Task { try? await AppStore.presentOfferCodeRedeemSheet(in: keyWindowScene()) }
            return
        }
        let urlString = "https://apps.apple.com/redeem?ctx=offercodes&id=\(appleId)&code=\(code)"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func keyWindowScene() -> UIWindowScene {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first!
    }
}
