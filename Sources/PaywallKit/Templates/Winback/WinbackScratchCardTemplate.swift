import SwiftUI

/// Winback: Scratch Card — gamified golden ticket with scratchable overlay.
/// Two phases: scratch to reveal, then claim the prize (free trial on yearly).
struct WinbackScratchCardTemplate: View {
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) -> Void
    let onClose: () -> Void

    @State private var isPurchasing = false
    @State private var scratchPoints: [CGPoint] = []
    @State private var scratchPercentage: CGFloat = 0

    private var yearlyProduct: PaywallProduct? {
        products.first { $0.period == .yearly }
            ?? products.first
    }

    private var isRevealed: Bool { scratchPercentage > 0.25 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header
                    Text("🎫")
                        .font(.system(size: 52))

                    VStack(spacing: 6) {
                        Text("You got a\nGolden Ticket!")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Scratch to reveal your exclusive deal")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Scratch card area
                    ZStack {
                        // Prize underneath
                        prizeView
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [theme.accent.opacity(0.15), theme.accent2.opacity(0.1)],
                                    startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(20)

                        // Golden scratchable overlay
                        if !isRevealed {
                            goldenOverlay
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(20)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.4), value: isRevealed)

                    if !isRevealed {
                        Text("👆 Scratch with your finger")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // CTA
                    VStack(spacing: 10) {
                        CTAButton(
                            title: isRevealed ? "Oh Yeah! Let's Go! 🎉" : "Start Free Trial",
                            theme: theme,
                            isLoading: isPurchasing
                        ) {
                            guard let id = yearlyProduct?.id else { return }
                            isPurchasing = true
                            onPurchase(id)
                        }

                        Text("Cancel anytime · No charge today")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.35))

                        RestoreButton(action: { })
                        LegalFooter(trialDays: yearlyProduct?.trialDays)
                    }

                    // Very subtle skip
                    Button(action: onClose) {
                        Text("No thanks")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.15))
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

    // MARK: - Prize (revealed after scratch)

    private var prizeView: some View {
        VStack(spacing: 6) {
            Text("🎉")
                .font(.system(size: 36))

            Text("FREE TRIAL")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(.white)
                .tracking(2)

            if let p = yearlyProduct {
                let perWeek = NSDecimalNumber(decimal: p.price).doubleValue / 52.0
                Text(String(format: "Just $%.2f/week", perWeek))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.accent)
            }
        }
    }

    // MARK: - Golden Overlay (scratchable)

    private var goldenOverlay: some View {
        Canvas { context, size in
            // Golden gradient background
            let gradient = Gradient(stops: [
                .init(color: Color(red: 0.83, green: 0.66, blue: 0.26), location: 0),
                .init(color: Color(red: 0.94, green: 0.82, blue: 0.38), location: 0.3),
                .init(color: Color(red: 0.83, green: 0.66, blue: 0.26), location: 0.7),
                .init(color: Color(red: 0.91, green: 0.78, blue: 0.29), location: 1.0),
            ])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(gradient,
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height))
            )

            // Dashed border
            let inset: CGFloat = 12
            let borderRect = CGRect(x: inset, y: inset,
                                    width: size.width - inset * 2,
                                    height: size.height - inset * 2)
            let borderPath = Path(roundedRect: borderRect, cornerRadius: 12)
            context.stroke(borderPath,
                with: .color(Color(red: 0.72, green: 0.58, blue: 0.12)),
                style: StrokeStyle(lineWidth: 2, dash: [6, 8]))

            // "SCRATCH HERE" text
            context.draw(
                Text("✨ SCRATCH HERE ✨")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.41, blue: 0.08)),
                at: CGPoint(x: size.width / 2, y: size.height / 2 - 12))

            context.draw(
                Text("Swipe to reveal your prize")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.55, green: 0.41, blue: 0.08)),
                at: CGPoint(x: size.width / 2, y: size.height / 2 + 14))

            // Erase where user scratched
            context.blendMode = .clear
            for point in scratchPoints {
                let rect = CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50)
                context.fill(Path(ellipseIn: rect), with: .color(.black))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    scratchPoints.append(value.location)
                    // Estimate percentage scratched
                    scratchPercentage = min(1, CGFloat(scratchPoints.count) / 60.0)
                }
        )
        .allowsHitTesting(!isRevealed)
    }
}
