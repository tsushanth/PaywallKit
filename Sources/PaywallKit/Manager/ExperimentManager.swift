import Foundation

/// Manages experiment assignment — assigns templates on install, supports server override.
@MainActor
public final class ExperimentManager: ObservableObject {
    public static let shared = ExperimentManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let userId = "pwkit_user_id"
        static let primaryTemplate = "pwkit_primary_template"
        static let winbackTemplate = "pwkit_winback_template"
        static let serverOverride = "pwkit_server_override"
        static let serverIsDismissible = "pwkit_server_dismissible"
        static let serverShowWinback = "pwkit_server_show_winback"
        static let lastServerCheck = "pwkit_last_server_check"
        static let impressionCount = "pwkit_impression_count"
    }

    // MARK: - User ID

    public var userId: String {
        if let existing = defaults.string(forKey: Keys.userId) { return existing }
        let id = UUID().uuidString
        defaults.set(id, forKey: Keys.userId)
        return id
    }

    // MARK: - Template Assignment

    /// Gets the primary template — server override > local assignment
    public func primaryTemplate() -> PrimaryTemplate {
        // Check server override first
        if let override = defaults.string(forKey: Keys.serverOverride + "_primary"),
           let template = PrimaryTemplate(rawValue: override) {
            return template
        }
        // Local assignment (random on first access, sticky after)
        if let stored = defaults.string(forKey: Keys.primaryTemplate),
           let template = PrimaryTemplate(rawValue: stored) {
            return template
        }
        // Default to valueStack — safe for App Store review, no urgency/timers
        let template = PrimaryTemplate.valueStack
        defaults.set(template.rawValue, forKey: Keys.primaryTemplate)
        return template
    }

    /// Gets the winback template — server override > local assignment
    public func winbackTemplate() -> WinbackTemplate {
        if let override = defaults.string(forKey: Keys.serverOverride + "_winback"),
           let template = WinbackTemplate(rawValue: override) {
            return template
        }
        if let stored = defaults.string(forKey: Keys.winbackTemplate),
           let template = WinbackTemplate(rawValue: stored) {
            return template
        }
        // Default to featureReminder — safe for review, no countdown/urgency
        let template = WinbackTemplate.featureReminder
        defaults.set(template.rawValue, forKey: Keys.winbackTemplate)
        return template
    }

    // MARK: - Debug Override

    /// Force a specific primary template for testing. Pass nil to clear.
    public func forceTemplate(primary: PrimaryTemplate?) {
        if let primary {
            defaults.set(primary.rawValue, forKey: Keys.serverOverride + "_primary")
        } else {
            defaults.removeObject(forKey: Keys.serverOverride + "_primary")
        }
    }

    /// Force a specific winback template for testing. Pass nil to clear.
    public func forceTemplate(winback: WinbackTemplate?) {
        if let winback {
            defaults.set(winback.rawValue, forKey: Keys.serverOverride + "_winback")
        } else {
            defaults.removeObject(forKey: Keys.serverOverride + "_winback")
        }
    }

    /// Force isDismissible for testing. Pass nil to clear.
    public func forceIsDismissible(_ value: Bool?) {
        if let value {
            defaults.set(value, forKey: Keys.serverIsDismissible)
        } else {
            defaults.removeObject(forKey: Keys.serverIsDismissible)
        }
    }

    /// Clear all debug overrides
    public func clearOverrides() {
        defaults.removeObject(forKey: Keys.serverOverride + "_primary")
        defaults.removeObject(forKey: Keys.serverOverride + "_winback")
        defaults.removeObject(forKey: Keys.serverIsDismissible)
        defaults.removeObject(forKey: Keys.serverShowWinback)
    }

    // MARK: - Impression Tracking

    /// Number of times the paywall has been shown for this app
    public func impressionCount(appId: String) -> Int {
        defaults.integer(forKey: "\(Keys.impressionCount)_\(appId)")
    }

    /// Increment impression count — called each time PaywallView is created
    public func incrementImpressions(appId: String) {
        let key = "\(Keys.impressionCount)_\(appId)"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    /// Whether the paywall should be dismissible — server can override to false for hard paywall
    public func isDismissible() -> Bool {
        if defaults.object(forKey: Keys.serverIsDismissible) != nil {
            return defaults.bool(forKey: Keys.serverIsDismissible)
        }
        return true // default: dismissible
    }

    /// Whether to show the winback after primary dismissal.
    /// Defaults to false (compliant baseline); server enables for repeat dismissers.
    public func showWinback() -> Bool {
        if defaults.object(forKey: Keys.serverShowWinback) != nil {
            return defaults.bool(forKey: Keys.serverShowWinback)
        }
        return false // default: no immediate winback — safe for App Store review
    }

    /// Force showWinback for testing. Pass nil to clear.
    public func forceShowWinback(_ value: Bool?) {
        if let value {
            defaults.set(value, forKey: Keys.serverShowWinback)
        } else {
            defaults.removeObject(forKey: Keys.serverShowWinback)
        }
    }

    // MARK: - Server Override

    /// Check server for template override (fire-and-forget, non-blocking)
    public func checkServerOverride(appId: String) {
        // Don't check more than once per hour
        if let last = defaults.object(forKey: Keys.lastServerCheck) as? Date,
           Date().timeIntervalSince(last) < 3600 { return }

        Task.detached(priority: .utility) {
            await self.fetchOverride(appId: appId)
        }
    }

    private func fetchOverride(appId: String) async {
        let apiBase = PaywallManager.shared.apiBase
        guard var components = URLComponents(string: "\(apiBase)/resolve") else { return }
        let impressions = await MainActor.run { impressionCount(appId: appId) }

        components.queryItems = [
            URLQueryItem(name: "app", value: appId),
            URLQueryItem(name: "placement", value: "onboarding"),
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "impressions", value: String(impressions)),
        ]
        guard let url = components.url else { return }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            await MainActor.run {
                if let primary = json["primaryTemplate"] as? String {
                    self.defaults.set(primary, forKey: Keys.serverOverride + "_primary")
                }
                if let winback = json["winbackTemplate"] as? String {
                    self.defaults.set(winback, forKey: Keys.serverOverride + "_winback")
                }
                if let dismissible = json["isDismissible"] as? Bool {
                    self.defaults.set(dismissible, forKey: Keys.serverIsDismissible)
                }
                if let showWinback = json["showWinback"] as? Bool {
                    self.defaults.set(showWinback, forKey: Keys.serverShowWinback)
                }
                self.defaults.set(Date(), forKey: Keys.lastServerCheck)
            }
        } catch { }
    }
}
