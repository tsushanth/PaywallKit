import Foundation

/// Handles event tracking to the PaywallKit API.
@MainActor
public final class PaywallManager {
    public static let shared = PaywallManager()

    let apiBase: String

    private init() {
        let info = Bundle.main.infoDictionary
        self.apiBase = info?["PaywallKitAPIBase"] as? String
            ?? "https://paywallkit-api-917362189743.us-central1.run.app"
    }

    // MARK: - Event Tracking

    /// Tracks a paywall event. Fire-and-forget.
    public func trackEvent(
        appId: String,
        placement: String,
        templateId: String,
        event: String,
        productId: String? = nil
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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        Task.detached(priority: .utility) {
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    // Legacy analytics handler (for Firebase/Mixpanel)
    public var analyticsHandler: ((_ event: String, _ params: [String: String]) -> Void)?
}
