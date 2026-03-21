import SwiftUI

/// Pattern 1: Anchor & Decoy (Calm, MacroFactor — $4M+/mo)
/// Monthly shown at full price as anchor, annual highlighted with massive savings badge.
/// Visual hierarchy guides users toward the annual plan.
struct AnchorDecoyTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var selectedId: String?
    @State private var isPurchasing = false

    private var yearly: PaywallProduct? { products.first { $0.period == .yearly } }
    private var monthly: PaywallProduct? { products.first { $0.period == .monthly } }

    private var savingsPercent: Int {
        guard let y = yearly, let m = monthly else { return 0 }
        let yearlyMonthly = NSDecimalNumber(decimal: y.price).doubleValue / 12.0
        let monthlyPrice = NSDecimalNumber(decimal: m.price).doubleValue
        guard monthlyPrice > 0 else { return 0 }
        return Int(((monthlyPrice - yearlyMonthly) / monthlyPrice) * 100)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(
                                LinearGradient(colors: [theme.accent, theme.accent2],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))

                        Text("Upgrade to \(appName)")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 56)

                    // Plan cards — annual is hero, monthly is anchor
                    VStack(spacing: 12) {
                        // Annual — highlighted
                        if let y = yearly {
                            planCard(product: y, isRecommended: true)
                        }
                        // Monthly — anchor (expensive per month)
                        if let m = monthly {
                            planCard(product: m, isRecommended: false)
                        }
                        // Lifetime if available
                        if let lt = products.first(where: { $0.period == .lifetime }) {
                            planCard(product: lt, isRecommended: false)
                        }
                    }

                    // Compact feature checks
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(features.prefix(5), id: \.title) { feat in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(theme.accent)
                                    .font(.system(size: 16))
                                Text(feat.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                    .padding(16)
                    .background(theme.cardBackground)
                    .cornerRadius(16)

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

            CloseButton(action: onClose)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .onAppear {
            selectedId = yearly?.id ?? products.first?.id
        }
    }

    @ViewBuilder
    private func planCard(product: PaywallProduct, isRecommended: Bool) -> some View {
        Button {
            selectedId = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.period.rawValue.capitalized)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        if isRecommended && savingsPercent > 0 {
                            Text("SAVE \(savingsPercent)%")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(colors: [theme.accent, theme.accent2],
                                                   startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(6)
                        }
                    }

                    if product.period == .yearly {
                        let perWeek = NSDecimalNumber(decimal: product.price).doubleValue / 52.0
                        Text("Just \(String(format: "$%.2f", perWeek))/week")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.accent)
                    } else if product.period == .lifetime {
                        Text("One-time purchase")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    if let days = product.trialDays, days > 0, days <= 30 {
                        Text("\(days)-day free trial")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.accent)
                    }
                }

                Spacer()

                Text(product.localizedPrice)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(product.id == selectedId
                ? theme.accent.opacity(0.1)
                : theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(product.id == selectedId ? theme.accent : Color.white.opacity(0.06),
                            lineWidth: product.id == selectedId ? 2 : 1))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private var selectedProduct: PaywallProduct? { products.first { $0.id == selectedId } }

    private var ctaTitle: String {
        guard let p = selectedProduct else { return "Continue" }
        if let days = p.trialDays, days > 0, days <= 30 { return "Start \(days)-Day Free Trial" }
        return p.period == .lifetime ? "Get Lifetime Access" : "Continue"
    }
}
