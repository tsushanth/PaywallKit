import SwiftUI

// MARK: - Shared components used across templates

struct ProductCard: View {
    let product: PaywallProduct
    let isSelected: Bool
    let theme: PaywallTheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                if product.period == .yearly {
                    Text("BEST VALUE")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(colors: [theme.accent, theme.accent2],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(6)
                } else if product.period == .lifetime {
                    Text("ONE-TIME")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(theme.accent.opacity(0.8))
                        .cornerRadius(6)
                }

                Text(product.period.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)

                Text(product.localizedPrice)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.white)

                Text(periodLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? theme.accent.opacity(0.08) : theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? theme.accent : Color.white.opacity(0.08), lineWidth: 2)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private var periodLabel: String {
        switch product.period {
        case .yearly:
            let perWeek = NSDecimalNumber(decimal: product.price).doubleValue / 52.0
            return String(format: "$%.2f/week", perWeek)
        case .monthly: return "per month"
        case .weekly: return "per week"
        case .lifetime: return "one-time"
        }
    }
}

struct CTAButton: View {
    let title: String
    let theme: PaywallTheme
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: [theme.accent, theme.accent2],
                               startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(16)
        }
        .disabled(isLoading)
    }
}

struct FeatureRow: View {
    let feature: PaywallFeature
    let theme: PaywallTheme

    /// Detect if icon is an SF Symbol name (contains a dot or is all ASCII) vs emoji
    private var isSFSymbol: Bool {
        feature.icon.contains(".") || feature.icon.allSatisfy(\.isASCII)
    }

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if isSFSymbol {
                    Image(systemName: feature.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(theme.accent)
                } else {
                    Text(feature.icon)
                        .font(.system(size: 20))
                }
            }
            .frame(width: 40, height: 40)
            .background(theme.accent.opacity(0.12))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                if !feature.description.isEmpty {
                    Text(feature.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()
        }
    }
}

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
    }
}

struct LegalFooter: View {
    let trialDays: Int?
    var termsURL: URL? = PaywallManager.shared.termsURL
    var privacyURL: URL? = PaywallManager.shared.privacyURL

    var body: some View {
        VStack(spacing: 6) {
            if let days = trialDays, days > 0, days <= 30 {
                Text("\(days)-day free trial, then auto-renews. Cancel anytime.")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.3))
            } else {
                Text("Recurring billing. Cancel anytime in Settings.")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.3))
            }

            HStack(spacing: 12) {
                if let url = termsURL {
                    Link("Terms of Use", destination: url)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                if termsURL != nil && privacyURL != nil {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.2))
                }
                if let url = privacyURL {
                    Link("Privacy Policy", destination: url)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.4))
                }
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
    }
}

struct RestoreButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Restore Purchases")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
