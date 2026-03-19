import SwiftUI

/// Winback 1: Last Chance — urgency + single best offer + trust signals
struct WinbackLastChanceTemplate: View {
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

            VStack {
                Spacer()

                VStack(spacing: 24) {
                    Text("🎁")
                        .font(.system(size: 56))

                    VStack(spacing: 6) {
                        Text("Wait — one last thing")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(.white)
                        Text("You're about to lose access to Premium features.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let product = bestProduct {
                        VStack(spacing: 10) {
                            Text(product.localizedPrice)
                                .font(.system(size: 42, weight: .black))
                                .foregroundColor(.white)
                            Text(periodText(product))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            if let days = product.trialDays, days > 0, days <= 30 {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(theme.accent)
                                        .font(.system(size: 14))
                                    Text("\(days)-day free trial")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(theme.accent)
                                }
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(theme.cardBackground)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.accent, lineWidth: 1.5))
                        .cornerRadius(20)
                    }

                    HStack(spacing: 16) {
                        Label("Cancel anytime", systemImage: "checkmark")
                        Label("4.8★", systemImage: "star.fill")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    CTAButton(title: ctaTitle, theme: theme, isLoading: isPurchasing) {
                        guard let id = bestProduct?.id else { return }
                        isPurchasing = true
                        onPurchase(id)
                    }
                    Button(action: onClose) {
                        Text("No thanks, I'll miss out")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.25))
                    }
                    LegalFooter(trialDays: bestProduct?.trialDays)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }

            CloseButton(action: onClose)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
    }

    private func periodText(_ p: PaywallProduct) -> String {
        switch p.period {
        case .yearly: return "per year · billed annually"
        case .monthly: return "per month"
        case .weekly: return "per week"
        case .lifetime: return "one-time · forever"
        }
    }

    private var ctaTitle: String {
        guard let p = bestProduct else { return "Get Premium" }
        if let days = p.trialDays, days > 0, days <= 30 { return "Start \(days)-Day Free Trial" }
        return "Get Premium"
    }
}
