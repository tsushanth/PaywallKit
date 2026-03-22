import SwiftUI

/// Pattern 2: Value Stack (MyFitnessPal $13M/mo, ChatOn $5M/mo)
/// Feature list with icons + action verbs ("Unlock", "Remove", "Access").
/// Scannable layout emphasizing concrete benefits you're paying for.
struct ValueStackTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var selectedId: String?
    @State private var isPurchasing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header with gradient text
                    VStack(spacing: 8) {
                        Text("Unlock \(appName)")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(.white)
                        Text("Everything included. No limits.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 56)

                    // Value stack — each feature is a "thing you get"
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.element.title) { idx, feat in
                            HStack(spacing: 14) {
                                IconView(icon: feat.icon, size: 22, color: theme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(theme.accent.opacity(0.1))
                                    .cornerRadius(12)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feat.title)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    if !feat.description.isEmpty {
                                        Text(feat.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }

                                Spacer()

                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(theme.accent)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)

                            if idx < features.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .background(theme.cardBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1))

                    // Products
                    HStack(spacing: 10) {
                        ForEach(sortedProducts, id: \.id) { product in
                            ProductCard(product: product, isSelected: product.id == selectedId,
                                        theme: theme, onTap: { selectedId = product.id })
                        }
                    }

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
        .onAppear { selectedId = sortedProducts.first?.id }
    }

    private var sortedProducts: [PaywallProduct] {
        let order: [PaywallProduct.Period] = [.yearly, .monthly, .weekly, .lifetime]
        return products.sorted { order.firstIndex(of: $0.period)! < order.firstIndex(of: $1.period)! }
    }
    private var selectedProduct: PaywallProduct? { products.first { $0.id == selectedId } }
    private var ctaTitle: String {
        guard let p = selectedProduct else { return "Continue" }
        if let days = p.trialDays, days > 0, days <= 30 { return "Start \(days)-Day Free Trial" }
        return p.period == .lifetime ? "Get Lifetime Access" : "Continue"
    }
}
