import SwiftUI

/// Pattern 4: Soft Commitment (Strava $11M/mo, Cal AI $2M/mo)
/// Trial-focused, zero-risk messaging. "Start Free Trial" CTA, explicit cancel anytime,
/// clear trial timeline. Removes purchase anxiety by emphasizing free + easy exit.
struct SoftCommitmentTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var isPurchasing = false

    private var bestProduct: PaywallProduct? {
        // Prefer product with trial
        products.first { $0.trialDays != nil && ($0.trialDays ?? 0) > 0 }
            ?? products.first { $0.period == .yearly }
            ?? products.first
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 32) {
                    // Friendly icon
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.12))
                            .frame(width: 100, height: 100)
                        Image(systemName: "gift.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(colors: [theme.accent, theme.accent2],
                                               startPoint: .top, endPoint: .bottom))
                    }

                    // Zero-risk headline
                    VStack(spacing: 10) {
                        if let days = bestProduct?.trialDays, days > 0, days <= 30 {
                            Text("Try Premium Free\nfor \(days) Days")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Unlock Premium")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(.white)
                        }

                        Text("No commitment. Cancel anytime.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }

                    // Trial timeline
                    if let days = bestProduct?.trialDays, days > 0, days <= 30 {
                        VStack(spacing: 0) {
                            timelineRow(icon: "checkmark.circle.fill", color: theme.accent,
                                        title: "Today", subtitle: "Get instant access to all features")
                            timelineConnector()
                            timelineRow(icon: "bell.fill", color: .orange,
                                        title: "Day \(days - 1)", subtitle: "We'll remind you before trial ends")
                            timelineConnector()
                            timelineRow(icon: "calendar", color: .secondary,
                                        title: "Day \(days)", subtitle: "Trial ends — only pay if you love it")
                        }
                        .padding(16)
                        .background(theme.cardBackground)
                        .cornerRadius(16)
                    }

                    // Quick features
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(features.prefix(4), id: \.title) { feat in
                            HStack(spacing: 10) {
                                Text(feat.icon)
                                    .font(.system(size: 16))
                                Text(feat.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA area
                VStack(spacing: 10) {
                    CTAButton(title: ctaTitle, theme: theme, isLoading: isPurchasing) {
                        guard let id = bestProduct?.id else { return }
                        isPurchasing = true
                        onPurchase(id)
                    }

                    if let p = bestProduct {
                        Text("Then \(p.localizedPrice)/\(periodShort(p)) · Cancel anytime")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    RestoreButton(action: onRestore)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }

            CloseButton(action: onClose)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
    }

    @ViewBuilder
    private func timelineRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func timelineConnector() -> some View {
        HStack {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 2, height: 20)
                .padding(.leading, 13)
            Spacer()
        }
    }

    private func periodShort(_ p: PaywallProduct) -> String {
        switch p.period {
        case .yearly: return "year"
        case .monthly: return "month"
        case .weekly: return "week"
        case .lifetime: return "lifetime"
        }
    }

    private var ctaTitle: String {
        if let days = bestProduct?.trialDays, days > 0, days <= 30 {
            return "Start Free \(days)-Day Trial"
        }
        return "Continue"
    }
}
