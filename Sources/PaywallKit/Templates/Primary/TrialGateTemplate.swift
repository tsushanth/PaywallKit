import SwiftUI

/// Pattern 6: Trial Gate (Hard Paywall)
/// Forces free trial signup on yearly plan. No close button. Payment method required
/// by Apple/Google for trial. After trial ends, auto-converts to yearly subscription.
/// Compliant with App Store 3.1.2 — not forcing payment, just trial signup.
struct TrialGateTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void
    let isDismissible: Bool

    @State private var isPurchasing = false

    /// Always selects yearly product with trial, falls back to any yearly
    private var yearlyProduct: PaywallProduct? {
        products.first { $0.period == .yearly && ($0.trialDays ?? 0) > 0 }
            ?? products.first { $0.period == .yearly }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Shield icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [theme.accent.opacity(0.2), theme.accent2.opacity(0.1)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 110, height: 110)
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(colors: [theme.accent, theme.accent2],
                                               startPoint: .top, endPoint: .bottom))
                    }

                    // Headline
                    VStack(spacing: 10) {
                        if let days = yearlyProduct?.trialDays, days > 0 {
                            Text("Start Your \(days)-Day\nFree Trial")
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Unlock \(appName)")
                                .font(.system(size: 30, weight: .heavy))
                                .foregroundColor(.white)
                        }

                        Text("Try everything free. Cancel anytime.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Trust badges
                    HStack(spacing: 20) {
                        trustBadge(icon: "creditcard.trianglebadge.exclamationmark", text: "No charge today")
                        trustBadge(icon: "bell.badge", text: "Reminder before trial ends")
                        trustBadge(icon: "xmark.circle", text: "Cancel anytime")
                    }
                    .padding(.horizontal, 8)

                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features.prefix(5), id: \.title) { feat in
                            FeatureRow(feature: feat, theme: theme)
                        }
                    }

                    // Trial timeline
                    if let days = yearlyProduct?.trialDays, days > 0 {
                        VStack(spacing: 0) {
                            timelineRow(icon: "checkmark.circle.fill", color: theme.accent,
                                        title: "Today — Free", subtitle: "Full access to all premium features")
                            timelineConnector()
                            timelineRow(icon: "bell.fill", color: .orange,
                                        title: "Day \(days - 1)", subtitle: "We'll remind you before trial ends")
                            timelineConnector()
                            timelineRow(icon: "dollarsign.circle", color: .secondary,
                                        title: "Day \(days)", subtitle: yearlyProduct.map { "Only \($0.localizedPrice)/year if you stay" } ?? "Subscription starts")
                        }
                        .padding(16)
                        .background(theme.cardBackground)
                        .cornerRadius(16)
                    }

                    // CTA
                    VStack(spacing: 10) {
                        CTAButton(title: ctaTitle, theme: theme, isLoading: isPurchasing) {
                            guard let id = yearlyProduct?.id else { return }
                            isPurchasing = true
                            onPurchase(id)
                        }

                        if let p = yearlyProduct {
                            if let days = p.trialDays, days > 0 {
                                Text("\(days) days free, then \(p.localizedPrice)/year")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            } else {
                                Text("\(p.localizedPrice)/year")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        RestoreButton(action: onRestore)
                        LegalFooter(trialDays: yearlyProduct?.trialDays)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, isDismissible ? 56 : 40)
                .padding(.bottom, 34)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }

            // Only show close button if dismissible
            if isDismissible {
                CloseButton(action: onClose)
                    .padding(.top, 16)
                    .padding(.trailing, 16)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func trustBadge(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(theme.accent)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
                    .foregroundColor(.white.opacity(0.7))
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

    private var ctaTitle: String {
        if let days = yearlyProduct?.trialDays, days > 0, days <= 30 {
            return "Start Free \(days)-Day Trial"
        }
        return "Subscribe Now"
    }
}
