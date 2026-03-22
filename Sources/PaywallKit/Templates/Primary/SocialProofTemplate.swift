import SwiftUI

/// Pattern 3: Social Proof Engine (Flo $9M/mo, YAZIO $3.3M/mo, Speak $2.8M/mo)
/// Hyper-specific user count, star rating, testimonials with context.
/// "Join 5 million users" + reviews reduce purchase anxiety via social validation.
struct SocialProofTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var selectedId: String?
    @State private var isPurchasing = false

    private let reviews = [
        (text: "This app literally changed my daily routine. Premium was the best decision.", author: "Sarah K.", stars: 5),
        (text: "I was skeptical but after one week with Premium, I'm never going back to free.", author: "Mike T.", stars: 5),
        (text: "Worth every penny. The extra features are exactly what I needed.", author: "Priya S.", stars: 5),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero stats
                        VStack(spacing: 16) {
                            // Rating
                            HStack(spacing: 4) {
                                ForEach(0..<5, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(theme.accent)
                                }
                                Text("4.8")
                                    .font(.system(size: 20, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(.leading, 4)
                            }

                            Text("Loved by 50,000+ users")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundColor(.white)

                            Text("Join thousands who upgraded and\nnever looked back.")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 56)

                        // Reviews
                        VStack(spacing: 10) {
                            ForEach(reviews, id: \.author) { review in
                                VStack(alignment: .leading, spacing: 8) {
                                    // Stars
                                    HStack(spacing: 2) {
                                        ForEach(0..<review.stars, id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(theme.accent)
                                        }
                                    }

                                    Text("\"\(review.text)\"")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.85))
                                        .italic()
                                        .lineSpacing(2)

                                    Text("— \(review.author)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1))
                                .cornerRadius(14)
                            }
                        }

                        // Quick feature checks
                        HStack(spacing: 0) {
                            ForEach(features.prefix(3), id: \.title) { feat in
                                VStack(spacing: 6) {
                                    IconView(icon: feat.icon, size: 24, color: theme.accent)
                                    Text(feat.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(14)
                        .background(theme.cardBackground)
                        .cornerRadius(14)

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
        guard let p = selectedProduct else { return "Join Premium" }
        if let days = p.trialDays, days > 0, days <= 30 { return "Start \(days)-Day Free Trial" }
        return "Join Premium"
    }
}
