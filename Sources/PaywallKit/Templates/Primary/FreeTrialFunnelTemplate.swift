import SwiftUI

/// 3-screen escalation funnel (Super/Duolingo pattern):
/// Screen 1: Dark — "TRY [APP] FOR $0.00" with features
/// Screen 2: Light — "COMPARE PLANS" with plan cards
/// Screen 3: Light — "Your one-time offer" with discount card
struct FreeTrialFunnelTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let isDismissible: Bool
    let onPurchase: (String) -> Void
    let onRestore: () -> Void
    let onClose: () -> Void

    @State private var currentStep = 0
    @State private var isPurchasing = false

    private var yearlyProduct: PaywallProduct? { products.first { $0.period == .yearly } }
    private var monthlyProduct: PaywallProduct? { products.first { $0.period == .monthly } }
    private var weeklyProduct: PaywallProduct? { products.first { $0.period == .weekly } }

    var body: some View {
        Group {
            switch currentStep {
            case 0:
                screen1
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)))
            case 1:
                screen2
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)))
            default:
                screen3
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }

    // MARK: - Screen 1: Dark — TRY FOR $0.00

    private var screen1: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.11, blue: 0.18),
                         Color(red: 0.10, green: 0.16, blue: 0.25),
                         Color(red: 0.06, green: 0.11, blue: 0.18)],
                startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Text("Unlock everything\nwith \(appName) Premium")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 48)

                    // Features
                    VStack(spacing: 0) {
                        ForEach(features.prefix(5), id: \.title) { feat in
                            HStack(spacing: 16) {
                                IconView(icon: feat.icon, size: 26, color: theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feat.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                    if !feat.description.isEmpty {
                                        Text(feat.description)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                    }

                    Spacer(minLength: 40)

                    Text("Cancel anytime, no penalties or fees")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))

                    // CTA
                    Button {
                        withAnimation { currentStep = 1 }
                    } label: {
                        Text("TRY \(appName.uppercased()) FOR $0.00")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(theme.accent)
                            .cornerRadius(14)
                    }

                    Button {
                        withAnimation { currentStep = 1 }
                    } label: {
                        Text("NO THANKS")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.accent)
                    }

                    LegalFooter(trialDays: yearlyProduct?.trialDays)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
        }
    }

    // MARK: - Screen 2: Light — COMPARE PLANS

    private var screen2: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        withAnimation { currentStep = 2 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .padding(8)
                    }

                    Text("COMPARE PLANS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black.opacity(0.7))
                        .tracking(1)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        if let yearly = yearlyProduct {
                            planCard(name: "Premium Yearly", product: yearly,
                                     featureCount: 4, isRecommended: true)
                        }
                        if let monthly = monthlyProduct {
                            planCard(name: "Premium Monthly", product: monthly,
                                     featureCount: 3, isRecommended: false)
                        }
                        if let weekly = weeklyProduct {
                            planCard(name: "Premium Weekly", product: weekly,
                                     featureCount: 2, isRecommended: false)
                        }

                        RestoreButton(action: onRestore)
                            .padding(.top, 8)

                        legalLinksLight
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }

            if isDismissible {
                Button {
                    withAnimation { currentStep = 2 }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.08))
                        .clipShape(Circle())
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
            }
        }
    }

    private func planCard(name: String, product: PaywallProduct,
                          featureCount: Int, isRecommended: Bool) -> some View {
        VStack(spacing: 0) {
            if isRecommended {
                Text("RECOMMENDED")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(theme.accent)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                }

                let period = product.period == .yearly ? "year" : product.period == .monthly ? "month" : "week"
                Text("Then \(product.localizedPrice)/\(period)")
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.45))

                ForEach(features.prefix(featureCount), id: \.title) { feat in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(theme.accent)
                        Text(feat.title)
                            .font(.system(size: 14))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }

                Button {
                    isPurchasing = true
                    onPurchase(product.id)
                } label: {
                    Text("TRY FOR $0.00")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(theme.accent, lineWidth: 1.5)
                        )
                }
            }
            .padding(20)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Light Legal Links (for light-background screens)

    private var legalLinksLight: some View {
        VStack(spacing: 4) {
            Text("Recurring billing. Cancel anytime in Settings.")
                .font(.system(size: 10))
                .foregroundColor(.black.opacity(0.35))

            HStack(spacing: 12) {
                if let url = PaywallManager.shared.termsURL {
                    Link("Terms of Use", destination: url)
                        .font(.system(size: 10))
                        .foregroundColor(.black.opacity(0.45))
                }
                Text("·")
                    .font(.system(size: 10))
                    .foregroundColor(.black.opacity(0.2))
                if let url = PaywallManager.shared.privacyURL {
                    Link("Privacy Policy", destination: url)
                        .font(.system(size: 10))
                        .foregroundColor(.black.opacity(0.45))
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Screen 3: Light — One-Time Offer

    private var screen3: some View {
        let product = yearlyProduct ?? monthlyProduct
        let discountPercent: Int = {
            guard let m = monthlyProduct, let y = yearlyProduct, m.price > 0 else { return 0 }
            let annualized = NSDecimalNumber(decimal: m.price).doubleValue * 12
            let yearly = NSDecimalNumber(decimal: y.price).doubleValue
            return Int((annualized - yearly) / annualized * 100)
        }()

        return ZStack(alignment: .topLeading) {
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("Your one-time offer")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.black)
                        .padding(.top, 48)

                    // Big dark discount card
                    VStack(spacing: 8) {
                        Text("✦  ✧  ✦")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.5))

                        Text(discountPercent > 0 ? "\(discountPercent)% OFF" : "BEST DEAL")
                            .font(.system(size: 44, weight: .black))
                            .foregroundColor(.white)

                        Text("FOREVER")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                            .tracking(6)

                        Text("✦  ✧  ✦")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.vertical, 32)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.10, green: 0.10, blue: 0.10))
                    .cornerRadius(20)

                    // Price
                    if let p = product {
                        HStack(spacing: 8) {
                            if let m = monthlyProduct, yearlyProduct != nil {
                                let annualized = NSDecimalNumber(decimal: m.price).doubleValue * 12
                                Text(String(format: "$%.2f", annualized))
                                    .font(.system(size: 18))
                                    .foregroundColor(.black.opacity(0.35))
                                    .strikethrough()
                            }
                            let divisor: Double = p.period == .yearly ? 12 : p.period == .weekly ? 0.25 : 1
                            let perMonth = NSDecimalNumber(decimal: p.price).doubleValue / divisor
                            Text(String(format: "$%.2f /mo", perMonth))
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.black)
                        }
                    }

                    Text("Once you close your one-time offer, it's gone!" +
                         (discountPercent > 0 ? "\nSave \(discountPercent)% with yearly plan" : ""))
                        .font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.45))
                        .multilineTextAlignment(.center)

                    // Plan card
                    if let p = product {
                        VStack(spacing: 0) {
                            if let days = p.trialDays, days > 0 {
                                Text("\(days)-DAY FREE TRIAL")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundColor(.white)
                                    .tracking(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Color.black)
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    let planName = p.period == .yearly ? "Yearly Plan" : p.period == .monthly ? "Monthly Plan" : "Weekly Plan"
                                    Text(planName)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                    Text("\(p.localizedPrice)/\(p.period.rawValue)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.black.opacity(0.5))
                                }
                                Spacer()
                                if p.period == .yearly {
                                    let perMonth = NSDecimalNumber(decimal: p.price).doubleValue / 12
                                    Text(String(format: "$%.2f /mo", perMonth))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .padding(16)
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    }

                    // CTA
                    Button {
                        guard let id = product?.id else { return }
                        isPurchasing = true
                        onPurchase(id)
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                Text("Start Free Trial")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black)
                        .cornerRadius(14)
                    }
                    .disabled(isPurchasing)

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                        Text("No Commitment - Cancel Anytime")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                    }

                    legalLinksLight
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.5))
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.08))
                    .clipShape(Circle())
            }
            .padding(.top, 16)
            .padding(.leading, 16)
        }
    }
}
