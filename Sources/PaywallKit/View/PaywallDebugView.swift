import SwiftUI

/// Drop-in debug menu for testing paywall templates.
/// Uses StoreManager for real StoreKit 2 products when available, falls back to mocks.
///
/// Usage in any app's settings:
/// ```swift
/// #if DEBUG
/// PaywallDebugView(
///     appId: "clearvoice",
///     appName: "ClearVoice Pro",
///     features: [...],
///     theme: myTheme
/// )
/// #endif
/// ```
public struct PaywallDebugView: View {
    let appId: String
    let appName: String
    let features: [PaywallFeature]
    let theme: PaywallTheme

    @State private var selectedPrimary: PrimaryTemplate = .valueStack
    @State private var selectedWinback: WinbackTemplate = .featureReminder
    @State private var isDismissible = true
    @State private var showPaywall = false

    @ObservedObject private var store = StoreManager.shared
    private let em = ExperimentManager.shared

    public init(
        appId: String,
        appName: String,
        features: [PaywallFeature],
        theme: PaywallTheme
    ) {
        self.appId = appId
        self.appName = appName
        self.features = features
        self.theme = theme
    }

    private var products: [PaywallProduct] {
        if store.paywallProducts.isEmpty {
            // Mock products when StoreManager not configured
            return [
                PaywallProduct(id: "weekly", localizedPrice: "$1.99", price: 1.99, currencyCode: "USD", trialDays: 3, period: .weekly),
                PaywallProduct(id: "monthly", localizedPrice: "$4.99", price: 4.99, currencyCode: "USD", trialDays: 7, period: .monthly),
                PaywallProduct(id: "yearly", localizedPrice: "$29.99", price: 29.99, currencyCode: "USD", trialDays: 7, period: .yearly),
            ]
        }
        return store.paywallProducts
    }

    public var body: some View {
        Section("Paywall Debug") {
            Picker("Primary", selection: $selectedPrimary) {
                ForEach(PrimaryTemplate.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }

            Picker("Winback", selection: $selectedWinback) {
                ForEach(WinbackTemplate.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }

            Toggle("Dismissible", isOn: $isDismissible)

            HStack {
                Text("Premium")
                Spacer()
                Text(store.isPremium ? "Active" : "Free")
                    .foregroundColor(store.isPremium ? .green : .secondary)
            }

            HStack {
                Text("Products")
                Spacer()
                Text("\(products.count) loaded")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Impressions")
                Spacer()
                Text("\(em.impressionCount(appId: appId))")
                    .foregroundColor(.secondary)
            }

            Button {
                em.forceTemplate(primary: selectedPrimary)
                em.forceTemplate(winback: selectedWinback)
                em.forceIsDismissible(isDismissible)
                showPaywall = true
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Show Paywall")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button("Clear Overrides", role: .destructive) {
                em.clearOverrides()
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(
                appId: appId,
                appName: appName,
                features: features,
                products: products,
                theme: theme,
                showWinback: true,
                isDismissible: isDismissible,
                onPurchase: { productId in
                    let result = await store.purchase(productId: productId)
                    if case .purchased = result {
                        await MainActor.run {
                            showPaywall = false
                            em.clearOverrides()
                        }
                    }
                    // If using mocks, simulate success
                    if store.paywallProducts.isEmpty {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        await MainActor.run {
                            showPaywall = false
                            em.clearOverrides()
                        }
                    }
                },
                onRestore: {
                    await store.restore()
                    if store.isPremium {
                        await MainActor.run {
                            showPaywall = false
                            em.clearOverrides()
                        }
                    }
                },
                onDismiss: {
                    showPaywall = false
                    em.clearOverrides()
                }
            )
        }
    }
}
