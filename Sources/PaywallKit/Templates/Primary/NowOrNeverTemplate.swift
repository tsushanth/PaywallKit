import SwiftUI

/// Pattern 5: Now-or-Never (Captions $2.3M/mo, Finch $1.8M/mo, YAZIO $3.3M/mo)
/// Big discount banner, countdown timer, urgency messaging.
/// Creates FOMO and loss aversion with limited-time pricing.
struct NowOrNeverTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var selectedId: String?
    @State private var isPurchasing = false
    @State private var timeRemaining: Int = 15 * 60 // 15 min countdown

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Discount banner
                        VStack(spacing: 4) {
                            Text("LIMITED TIME OFFER")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(2)
                                .foregroundColor(theme.accent)

                            Text("50% OFF")
                                .font(.system(size: 48, weight: .black))
                                .foregroundStyle(
                                    LinearGradient(colors: [theme.accent, theme.accent2],
                                                   startPoint: .leading, endPoint: .trailing))

                            Text("Unlock \(appName)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 56)

                        // Countdown timer
                        HStack(spacing: 12) {
                            timerBlock(value: timeRemaining / 3600, label: "HRS")
                            Text(":")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(theme.accent)
                            timerBlock(value: (timeRemaining % 3600) / 60, label: "MIN")
                            Text(":")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(theme.accent)
                            timerBlock(value: timeRemaining % 60, label: "SEC")
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(theme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.accent.opacity(0.3), lineWidth: 1))
                        .cornerRadius(16)

                        // Features (compact)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(features.prefix(6), id: \.title) { feat in
                                HStack(spacing: 6) {
                                    Text(feat.icon)
                                        .font(.system(size: 14))
                                    Text(feat.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.accent.opacity(0.08))
                                .cornerRadius(10)
                            }
                        }

                        // Products
                        HStack(spacing: 10) {
                            ForEach(sortedProducts, id: \.id) { product in
                                ProductCard(product: product, isSelected: product.id == selectedId,
                                            theme: theme, onTap: { selectedId = product.id })
                            }
                        }

                        // Urgency text
                        Text("⚡ This price disappears when you leave this page")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.accent.opacity(0.8))
                            .multilineTextAlignment(.center)

                        // CTA
                        VStack(spacing: 10) {
                            CTAButton(title: ctaTitle, theme: theme, isLoading: isPurchasing) {
                                guard let id = selectedId else { return }
                                isPurchasing = true
                                onPurchase(id)
                            }
                            RestoreButton(action: onRestore)
                            LegalFooter(trialDays: selectedProduct?.trialDays)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                }
            }

            CloseButton(action: onClose)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .onAppear { selectedId = sortedProducts.first?.id }
        .onReceive(timer) { _ in
            if timeRemaining > 0 { timeRemaining -= 1 }
        }
    }

    @ViewBuilder
    private func timerBlock(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .tracking(1)
        }
    }

    private var sortedProducts: [PaywallProduct] {
        let order: [PaywallProduct.Period] = [.yearly, .monthly, .weekly, .lifetime]
        return products.sorted { order.firstIndex(of: $0.period)! < order.firstIndex(of: $1.period)! }
    }
    private var selectedProduct: PaywallProduct? { products.first { $0.id == selectedId } }
    private var ctaTitle: String {
        guard let p = selectedProduct else { return "Claim Offer" }
        if let days = p.trialDays, days > 0, days <= 30 { return "Start \(days)-Day Free Trial" }
        return "Claim Offer — \(p.localizedPrice)"
    }
}
