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
        static let lastServerCheck = "pwkit_last_server_check"
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
        components.queryItems = [
            URLQueryItem(name: "app", value: appId),
            URLQueryItem(name: "placement", value: "onboarding"),
            URLQueryItem(name: "userId", value: userId),
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
                self.defaults.set(Date(), forKey: Keys.lastServerCheck)
            }
        } catch { }
    }
}
