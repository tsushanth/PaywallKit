import SwiftUI

/// Drop-in debug menu for testing paywall templates.
/// Shows template pickers + a "Show Paywall" button that presents the selected combination.
///
/// Usage in any app's settings:
/// ```swift
/// #if DEBUG
/// PaywallDebugView(
///     appId: "clearvoice",
///     appName: "ClearVoice Pro",
///     features: [...],
///     products: paywallProducts,
///     theme: myTheme,
///     onPurchase: { id in ... },
///     onRestore: { ... }
/// )
/// #endif
/// ```
public struct PaywallDebugView: View {
    let appId: String
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) async -> Void
    let onRestore: () async -> Void

    @State private var selectedPrimary: PrimaryTemplate = .valueStack
    @State private var selectedWinback: WinbackTemplate = .featureReminder
    @State private var isDismissible = true
    @State private var showPaywall = false

    private let em = ExperimentManager.shared

    public init(
        appId: String,
        appName: String,
        features: [PaywallFeature],
        products: [PaywallProduct],
        theme: PaywallTheme,
        onPurchase: @escaping (String) async -> Void,
        onRestore: @escaping () async -> Void
    ) {
        self.appId = appId
        self.appName = appName
        self.features = features
        self.products = products
        self.theme = theme
        self.onPurchase = onPurchase
        self.onRestore = onRestore
    }

    public var body: some View {
        Section("Paywall Debug") {
            // Primary template picker
            Picker("Primary", selection: $selectedPrimary) {
                ForEach(PrimaryTemplate.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }

            // Winback template picker
            Picker("Winback", selection: $selectedWinback) {
                ForEach(WinbackTemplate.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }

            // Dismissible toggle
            Toggle("Dismissible", isOn: $isDismissible)

            // Info
            HStack {
                Text("Impressions")
                Spacer()
                Text("\(em.impressionCount(appId: appId))")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("User ID")
                Spacer()
                Text(String(em.userId.prefix(8)) + "...")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, design: .monospaced))
            }

            // Show paywall button
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

            // Clear overrides
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
                onPurchase: onPurchase,
                onRestore: onRestore,
                onDismiss: {
                    showPaywall = false
                    em.clearOverrides()
                }
            )
        }
    }
}
