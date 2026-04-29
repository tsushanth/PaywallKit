import SwiftUI

// MARK: - Product (RC-agnostic)

public struct PaywallProduct: Sendable, Equatable {
    public let id: String
    public let localizedPrice: String
    public let price: Decimal
    public let currencyCode: String
    public let trialDays: Int?
    public let period: Period

    public enum Period: String, Sendable {
        case weekly, monthly, yearly, lifetime
    }

    public init(id: String, localizedPrice: String, price: Decimal,
                currencyCode: String, trialDays: Int? = nil, period: Period) {
        self.id = id
        self.localizedPrice = localizedPrice
        self.price = price
        self.currencyCode = currencyCode
        self.trialDays = trialDays
        self.period = period
    }
}

// MARK: - Feature row

public struct PaywallFeature {
    public let icon: String
    public let title: String
    public let description: String

    public init(icon: String, title: String, description: String = "") {
        self.icon = icon
        self.title = title
        self.description = description
    }
}

// MARK: - App theme

public struct PaywallTheme {
    public let accent: Color
    public let accent2: Color
    public let background: Color
    public let cardBackground: Color

    public init(accent: Color, accent2: Color,
                background: Color = Color(red: 0.04, green: 0.04, blue: 0.06),
                cardBackground: Color = Color(red: 0.08, green: 0.08, blue: 0.12)) {
        self.accent = accent
        self.accent2 = accent2
        self.background = background
        self.cardBackground = cardBackground
    }
}

// MARK: - Template identifiers (5 proven patterns + 3 winbacks)

public enum PrimaryTemplate: String, CaseIterable, Codable, Sendable {
    case anchorDecoy       // Calm/MacroFactor: Monthly at high price, annual highlighted with savings
    case valueStack        // MyFitnessPal/ChatOn: Feature list with icons + action verbs
    case socialProof       // Flo/YAZIO: User counts, star ratings, testimonials
    case softCommitment    // Strava/Cal AI: Trial-focused, "Cancel anytime", low-risk messaging
    case nowOrNever        // Captions/Finch: Countdown timer, big discount banner, urgency
    case trialGate         // Hard paywall: yearly trial only, no close button, payment method required
    case freeTrialFunnel   // 3-screen escalation: features → compare plans → one-time offer
}

public enum WinbackTemplate: String, CaseIterable, Codable, Sendable {
    case lastChance        // Urgency + single best offer
    case featureReminder   // "Here's what you're missing" + feature cards
    case discountOffer     // Post-close welcome offer with 24hr timer (Adapty pattern)
    case scratchCard       // Gamified golden ticket scratch-to-reveal
    case spinWheel         // Gamified spin-the-wheel with spring animation
}
