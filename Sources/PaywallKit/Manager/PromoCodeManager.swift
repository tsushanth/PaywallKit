import UIKit

/// Detects, persists, and surfaces promo codes (e.g. "FOCUS30") from:
///   1. Deep link / universal link URL on launch
///   2. Clipboard — checked once per launch if no deep link found
///
/// The active code is automatically attached to every `trackEvent()` call
/// until the user converts (purchased/trial_started), after which it clears.
///
/// Usage — call from AppDelegate / SceneDelegate on launch:
///
///     // Scene-based:
///     func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
///                options connectionOptions: UIScene.ConnectionOptions) {
///         if let url = connectionOptions.urlContexts.first?.url {
///             PromoCodeManager.shared.handleURL(url)
///         } else if let activity = connectionOptions.userActivities.first {
///             PromoCodeManager.shared.handleUserActivity(activity)
///         } else {
///             Task { await PromoCodeManager.shared.checkClipboard() }
///         }
///     }
///
///     // URL scheme opened after launch:
///     func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
///         if let url = urlContexts.first?.url {
///             PromoCodeManager.shared.handleURL(url)
///         }
///     }
///
///     // Universal link:
///     func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
///         PromoCodeManager.shared.handleUserActivity(userActivity)
///     }

@available(iOS 16.0, *)
@MainActor
public final class PromoCodeManager {

    public static let shared = PromoCodeManager()
    private init() {}

    // UserDefaults keys
    private let codeKey    = "pwkit_promo_code"
    private let variantKey = "pwkit_promo_variant"
    private let checkedKey = "pwkit_promo_clipboard_checked"

    // Regex: 4-8 uppercase letters followed by 1-3 digits (covers FOCUS30, BINGE30, FUTURE30, etc.)
    private let codePattern = try! NSRegularExpression(pattern: #"[A-Z]{3,8}\d{1,3}"#)

    // MARK: - Public API

    /// The active promo code, if one was detected and not yet converted.
    public var activeCode: String? {
        UserDefaults.standard.string(forKey: codeKey)
    }

    /// The PaywallKit variant ID associated with the active code.
    public var activeVariantId: String? {
        UserDefaults.standard.string(forKey: variantKey)
    }

    /// Call from SceneDelegate when a URL is opened (deep link or universal link).
    public func handleURL(_ url: URL) {
        guard let code = extractCode(from: url.absoluteString) else { return }
        persist(code: code)
    }

    /// Call from SceneDelegate when a universal link NSUserActivity arrives.
    public func handleUserActivity(_ activity: NSUserActivity) {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL else { return }
        handleURL(url)
    }

    /// Checks the clipboard for a promo code — call once on first launch if no deep link.
    /// Only reads clipboard once per app session (guarded by UserDefaults flag).
    public func checkClipboard() async {
        guard !UserDefaults.standard.bool(forKey: checkedKey) else { return }
        UserDefaults.standard.set(true, forKey: checkedKey)

        guard UIPasteboard.general.hasStrings,
              let text = UIPasteboard.general.string else { return }

        // Only accept clipboard codes if they look like a pure promo code (not arbitrary text)
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard stripped.count <= 12, codePattern.firstMatch(
            in: stripped, range: NSRange(stripped.startIndex..., in: stripped)
        ) != nil else { return }

        persist(code: stripped)
    }

    /// Called by PaywallManager after a successful /redeem-promo response to store the variant.
    public func store(code: String, variantId: String?) {
        persist(code: code)
        if let variantId {
            UserDefaults.standard.set(variantId, forKey: variantKey)
        }
    }

    /// Call after a successful purchase or trial start so the code isn't re-sent indefinitely.
    public func clearAfterConversion() {
        UserDefaults.standard.removeObject(forKey: codeKey)
        UserDefaults.standard.removeObject(forKey: variantKey)
        UserDefaults.standard.removeObject(forKey: checkedKey) // allow clipboard re-check on reinstall
    }

    // MARK: - Private

    private func extractCode(from string: String) -> String? {
        // First check query param: ?code=FOCUS30 or ?promo=FOCUS30
        if let components = URLComponents(string: string) {
            let queryNames = ["code", "promo", "promoCode", "offer"]
            for item in components.queryItems ?? [] {
                if queryNames.contains(item.name.lowercased()),
                   let value = item.value?.uppercased(),
                   isValidCode(value) {
                    return value
                }
            }
        }

        // Fall back to regex match anywhere in the string
        let upper = string.uppercased()
        let range = NSRange(upper.startIndex..., in: upper)
        guard let match = codePattern.firstMatch(in: upper, range: range),
              let swiftRange = Range(match.range, in: upper)
        else { return nil }

        let candidate = String(upper[swiftRange])
        return isValidCode(candidate) ? candidate : nil
    }

    private func isValidCode(_ candidate: String) -> Bool {
        guard (4...12).contains(candidate.count) else { return false }
        let range = NSRange(candidate.startIndex..., in: candidate)
        return codePattern.firstMatch(in: candidate, range: range) != nil
    }

    private func persist(code: String) {
        guard activeCode == nil else { return } // don't overwrite an existing code
        UserDefaults.standard.set(code, forKey: codeKey)
        print("[PromoCodeManager] Detected code: \(code)")
    }
}
