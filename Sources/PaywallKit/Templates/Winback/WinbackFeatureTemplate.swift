import SwiftUI

/// Winback 2: Feature Reminder — "Here's what you're missing" with feature cards
struct WinbackFeatureTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onClose: () -> Void

    @State private var isPurchasing = false

    private var bestProduct: PaywallProduct? {
        products.first { $0.period == .yearly }
            ?? products.first { $0.period == .monthly }
            ?? products.first
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("You're missing out on")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(appName)")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(
                                LinearGradient(colors: [theme.accent, theme.accent2],
                                               startPoint: .leading, endPoint: .trailing))
                    }
                    .padding(.top, 56)

                    VStack(spacing: 10) {
                        ForEach(features.prefix(5), id: \.title) { feat in
                            FeatureRow(feature: feat, theme: theme)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(theme.cardBackground)
                                .cornerRadius(14)
                        }
                    }

                    if let product = bestProduct {
                        VStack(spacing: 6) {
                            Text(product.localizedPrice)
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundColor(.white)
                            Text(periodText(product))
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(theme.accent, lineWidth: 1.5))
                        .cornerRadius(18)
                    }

                    // CTA
                    VStack(spacing: 12) {
                        CTAButton(title: ctaTitle, theme: theme, isLoading: isPurchasing) {
                            guard let id = bestProduct?.id else { return }
                            isPurchasing = true
                            onPurchase(id)
                        }
                        Button(action: onClose) {
                            Text("No thanks")
                                .font(.system(size: 13))
                                .foregroundColor(Color.white.opacity(0.25))
                        }
                        LegalFooter(trialDays: bestProduct?.trialDays)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }

            CloseButton(action: onClose)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
    }

    private func periodText(_ p: PaywallProduct) -> String {
        switch p.period {
        case .yearly: return "per year"
        case .monthly: return "per month"
        case .weekly: return "per week"
        case .lifetime: return "one-time"
        }
    }

    private var ctaTitle: String {
        guard let p = bestProduct else { return "Get Premium" }
        if let days = p.trialDays, days > 0, days <= 30 { return "Start \(days)-Day Free Trial" }
        return "Get Premium"
    }
}
