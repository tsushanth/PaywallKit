import SwiftUI

/// Winback: Spin Wheel — gamified spin-the-wheel with smooth iOS spring animation.
/// All segments are free trial offers. Wheel is rigged to land on yearly trial.
struct WinbackSpinWheelTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onClose: () -> Void

    private struct Prize {
        let label: String
        let emoji: String
        let period: PaywallProduct.Period
    }

    private let prizes: [Prize] = [
        Prize(label: "Free Trial\nWeekly", emoji: "🎁", period: .weekly),
        Prize(label: "Free Trial\nYearly", emoji: "⭐", period: .yearly),
        Prize(label: "Free Trial\nMonthly", emoji: "🎉", period: .monthly),
        Prize(label: "Free Trial\nWeekly", emoji: "✨", period: .weekly),
        Prize(label: "Free Trial\nYearly", emoji: "💎", period: .yearly),
        Prize(label: "Free Trial\nMonthly", emoji: "🔥", period: .monthly),
        Prize(label: "Free Trial\nYearly", emoji: "🎁", period: .yearly),
        Prize(label: "Free Trial\nWeekly", emoji: "⭐", period: .weekly),
    ]

    private let segmentColors: [Color] = [
        Color(red: 0.30, green: 0.69, blue: 0.31),
        Color(red: 0.13, green: 0.59, blue: 0.95),
        Color(red: 0.61, green: 0.15, blue: 0.69),
        Color(red: 1.00, green: 0.60, blue: 0.00),
        Color(red: 0.00, green: 0.74, blue: 0.83),
        Color(red: 0.96, green: 0.26, blue: 0.21),
        Color(red: 0.40, green: 0.23, blue: 0.72),
        Color(red: 1.00, green: 0.34, blue: 0.13),
    ]

    // Rig to land on index 1 (yearly)
    private let targetIndex = 1

    @State private var hasSpun = false
    @State private var showResult = false
    @State private var isPurchasing = false
    @State private var wheelRotation: Double = 0

    private var yearlyProduct: PaywallProduct? {
        products.first { $0.period == .yearly } ?? products.first
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    Text("🎰")
                        .font(.system(size: 48))

                    VStack(spacing: 4) {
                        Text("Spin to Win!")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.white)

                        Text("Try your luck for an exclusive deal")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Wheel
                    ZStack {
                        // Outer frame
                        Circle()
                            .fill(Color(red: 0.16, green: 0.16, blue: 0.24))
                            .frame(width: 290, height: 290)

                        // Wheel segments
                        wheelView
                            .frame(width: 264, height: 264)
                            .rotationEffect(.degrees(wheelRotation))

                        // Center button
                        Button(action: spin) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [theme.accent, theme.accent2],
                                        startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Text(hasSpun ? "🤞" : "SPIN")
                                        .font(.system(size: hasSpun ? 22 : 12, weight: .black))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: theme.accent.opacity(0.5), radius: 8)
                        }
                        .disabled(hasSpun)

                        // Pointer (top)
                        VStack {
                            Triangle()
                                .fill(theme.accent)
                                .frame(width: 20, height: 16)
                                .shadow(color: .black.opacity(0.5), radius: 2)
                            Spacer()
                        }
                        .frame(height: 290)
                    }
                    .padding(.vertical, 8)

                    // Prompt or result
                    if showResult {
                        resultView
                            .transition(.scale.combined(with: .opacity))
                    } else if !hasSpun {
                        Text("👆 TAP THE WHEEL TO SPIN")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.accent)
                            .tracking(1)
                    } else {
                        Text("Spinning... 🤞")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Skip (before spin only)
                    if !hasSpun {
                        Button(action: onClose) {
                            Text("No thanks")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.15))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 34)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }

            CloseButton(action: onClose)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
    }

    // MARK: - Wheel

    private var wheelView: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let segmentAngle = (2 * .pi) / Double(prizes.count)

            for i in 0..<prizes.count {
                let startAngle = Double(i) * segmentAngle - .pi / 2
                let endAngle = startAngle + segmentAngle

                // Segment
                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                            startAngle: .radians(startAngle),
                            endAngle: .radians(endAngle),
                            clockwise: false)
                path.closeSubpath()
                context.fill(path, with: .color(segmentColors[i % segmentColors.count]))

                // Divider line
                let divEnd = CGPoint(
                    x: center.x + radius * cos(startAngle),
                    y: center.y + radius * sin(startAngle))
                var divider = Path()
                divider.move(to: center)
                divider.addLine(to: divEnd)
                context.stroke(divider, with: .color(.white.opacity(0.4)), lineWidth: 1)

                // Label
                let midAngle = startAngle + segmentAngle / 2
                let labelRadius = radius * 0.62
                let labelPoint = CGPoint(
                    x: center.x + labelRadius * cos(midAngle),
                    y: center.y + labelRadius * sin(midAngle))

                context.draw(
                    Text(prizes[i].emoji)
                        .font(.system(size: 18)),
                    at: CGPoint(x: labelPoint.x, y: labelPoint.y - 8))

                context.draw(
                    Text(prizes[i].label)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white),
                    at: CGPoint(x: labelPoint.x, y: labelPoint.y + 10))
            }
        }
        .clipShape(Circle())
    }

    // MARK: - Result

    private var resultView: some View {
        VStack(spacing: 12) {
            Text("🎉 YOU WON! 🎉")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(theme.accent)

            // Prize card
            VStack(spacing: 8) {
                let prize = prizes[targetIndex]
                Text(prize.emoji)
                    .font(.system(size: 52))

                Text(prize.label.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                if let p = yearlyProduct {
                    let trialDays = p.trialDays ?? 3
                    Text("\(trialDays)-day free trial")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.accent)

                    Text("Then \(p.localizedPrice)/year")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [theme.accent.opacity(0.1), .clear],
                    startPoint: .top, endPoint: .bottom)
            )
            .background(theme.cardBackground)
            .cornerRadius(20)

            CTAButton(title: "🎁 Claim My Prize", theme: theme, isLoading: isPurchasing) {
                guard let id = yearlyProduct?.id else { return }
                isPurchasing = true
                onPurchase(id)
            }

            Text("Cancel anytime during trial · No charge today")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            RestoreButton(action: { })
            LegalFooter(trialDays: yearlyProduct?.trialDays)
        }
    }

    // MARK: - Spin Logic

    private func spin() {
        guard !hasSpun else { return }
        hasSpun = true

        let segmentAngle = 360.0 / Double(prizes.count)
        // Land in center of target segment, add full rotations for dramatic spin
        let targetDegrees = 360.0 - (Double(targetIndex) * segmentAngle + segmentAngle / 2.0)
        let totalRotation = 360.0 * 5 + targetDegrees // 5 full spins + landing

        withAnimation(.interpolatingSpring(stiffness: 15, damping: 12).speed(0.3)) {
            wheelRotation = totalRotation
        }

        // Show result after spin completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showResult = true
            }
        }
    }
}

// MARK: - Triangle Shape (pointer)

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
