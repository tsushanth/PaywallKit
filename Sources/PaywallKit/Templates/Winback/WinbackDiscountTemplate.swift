import SwiftUI

/// Winback 3: Post-Close Discount (Adapty pattern — standard in top apps)
/// Shows after primary paywall close with a time-limited discounted annual plan.
/// 24hr countdown creates urgency on second chance.
struct WinbackDiscountTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onClose: () -> Void

    @State private var isPurchasing = false
    @State private var timeRemaining: Int = 24 * 60 * 60 // 24hrs

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

                VStack(spacing: 28) {
                    // Discount badge
                    Text("EXCLUSIVE OFFER")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(2)
                        .foregroundColor(theme.accent)

                    // Big discount
                    VStack(spacing: 4) {
                        Text("50% OFF")
                            .font(.system(size: 52, weight: .black))
                            .foregroundStyle(
                                LinearGradient(colors: [theme.accent, theme.accent2],
                                               startPoint: .leading, endPoint: .trailing))

                        Text("\(appName)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }

                    // Countdown
                    VStack(spacing: 6) {
                        Text("Offer expires in")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            countdownUnit(value: timeRemaining / 3600, label: "hr")
                            Text(":")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.secondary)
                            countdownUnit(value: (timeRemaining % 3600) / 60, label: "min")
                            Text(":")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.secondary)
                            countdownUnit(value: timeRemaining % 60, label: "sec")
                        }
                    }
                    .padding(16)
                    .background(theme.cardBackground)
                    .cornerRadius(14)

                    // Price
                    if let product = bestProduct {
                        VStack(spacing: 6) {
                            Text(product.localizedPrice)
                                .font(.system(size: 36, weight: .heavy))
                                .foregroundColor(.white)
                            Text(periodText(product))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            if let days = product.trialDays, days > 0, days <= 30 {
                                Text("Includes \(days)-day free trial")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(theme.accent)
                                    .padding(.top, 2)
                            }
                        }
                    }
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
                        Text("I don't want 50% off")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.25))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }

            CloseButton(action: onClose)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 { timeRemaining -= 1 }
        }
    }

    @ViewBuilder
    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
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
        guard let p = bestProduct else { return "Claim 50% Off" }
        if let days = p.trialDays, days > 0, days <= 30 { return "Start \(days)-Day Free Trial" }
        return "Claim 50% Off"
    }
}
