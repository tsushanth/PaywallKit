import SwiftUI

/// Drop-in SwiftUI paywall with native templates, winback, and experiment tracking.
public struct PaywallView: View {
    let appId: String
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) async -> Void
    let onRestore: () async -> Void
    let onDismiss: () -> Void
    let showWinback: Bool

    @State private var didPurchase = false
    @State private var showingWinback = false

    private let primaryTemplate: PrimaryTemplate
    private let winbackTemplate: WinbackTemplate

    public init(
        appId: String,
        appName: String = "",
        features: [PaywallFeature] = [],
        products: [PaywallProduct],
        theme: PaywallTheme = PaywallTheme(accent: .blue, accent2: .purple),
        showWinback: Bool = true,
        onPurchase: @escaping (String) async -> Void,
        onRestore: @escaping () async -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.appId = appId
        self.appName = appName
        self.features = features
        self.products = products
        self.theme = theme
        self.showWinback = showWinback
        self.onPurchase = onPurchase
        self.onRestore = onRestore
        self.onDismiss = onDismiss

        let em = ExperimentManager.shared
        self.primaryTemplate = em.primaryTemplate()
        self.winbackTemplate = em.winbackTemplate()
    }

    public var body: some View {
        Group {
            if showingWinback {
                winbackView
                    .transition(.move(edge: .trailing))
            } else {
                primaryView
            }
        }
        .onAppear {
            PaywallManager.shared.trackEvent(
                appId: appId, placement: "onboarding",
                templateId: primaryTemplate.rawValue, event: "viewed")
            ExperimentManager.shared.checkServerOverride(appId: appId)
        }
    }

    // MARK: - Primary

    @ViewBuilder
    private var primaryView: some View {
        switch primaryTemplate {
        case .anchorDecoy:
            AnchorDecoyTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handlePurchase, onRestore: handleRestore,
                onClose: handleClose)
        case .valueStack:
            ValueStackTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handlePurchase, onRestore: handleRestore,
                onClose: handleClose)
        case .socialProof:
            SocialProofTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handlePurchase, onRestore: handleRestore,
                onClose: handleClose)
        case .softCommitment:
            SoftCommitmentTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handlePurchase, onRestore: handleRestore,
                onClose: handleClose)
        case .nowOrNever:
            NowOrNeverTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handlePurchase, onRestore: handleRestore,
                onClose: handleClose)
        }
    }

    // MARK: - Winback

    @ViewBuilder
    private var winbackView: some View {
        switch winbackTemplate {
        case .lastChance:
            WinbackLastChanceTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handleWinbackPurchase,
                onClose: handleWinbackClose)
        case .featureReminder:
            WinbackFeatureTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handleWinbackPurchase,
                onClose: handleWinbackClose)
        case .discountOffer:
            WinbackDiscountTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handleWinbackPurchase,
                onClose: handleWinbackClose)
        }
    }

    // MARK: - Handlers

    private func handlePurchase(_ productId: String) {
        didPurchase = true
        PaywallManager.shared.trackEvent(
            appId: appId, placement: "onboarding",
            templateId: primaryTemplate.rawValue, event: "purchased",
            productId: productId)
        Task { await onPurchase(productId) }
    }

    private func handleRestore() {
        PaywallManager.shared.trackEvent(
            appId: appId, placement: "onboarding",
            templateId: primaryTemplate.rawValue, event: "restored")
        Task { await onRestore() }
    }

    private func handleClose() {
        PaywallManager.shared.trackEvent(
            appId: appId, placement: "onboarding",
            templateId: primaryTemplate.rawValue, event: "closed")
        if !didPurchase && showWinback {
            PaywallManager.shared.trackEvent(
                appId: appId, placement: "winback",
                templateId: winbackTemplate.rawValue, event: "winback_shown")
            withAnimation(.easeInOut(duration: 0.3)) { showingWinback = true }
        } else {
            onDismiss()
        }
    }

    private func handleWinbackPurchase(_ productId: String) {
        PaywallManager.shared.trackEvent(
            appId: appId, placement: "winback",
            templateId: winbackTemplate.rawValue, event: "winback_purchased",
            productId: productId)
        Task { await onPurchase(productId) }
    }

    private func handleWinbackClose() {
        PaywallManager.shared.trackEvent(
            appId: appId, placement: "winback",
            templateId: winbackTemplate.rawValue, event: "winback_closed")
        onDismiss()
    }
}
