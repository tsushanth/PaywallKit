import SwiftUI
import StoreKit

/// Drop-in SwiftUI paywall with native templates, winback, and experiment tracking.
public struct PaywallView: View {
    let appId: String
    let placement: String
    let appName: String
    let features: [PaywallFeature]
    let products: [PaywallProduct]
    let theme: PaywallTheme
    let onPurchase: (String) async -> Bool
    let onRestore: () async -> Void
    let onDismiss: () -> Void
    let showWinback: Bool
    let isDismissible: Bool
    let termsURL: URL?
    let privacyURL: URL?
    /// Offer code for the promotional offer shown in the win-back flow (e.g. "winback_7day_free").
    /// When set, win-back purchases will be signed via the PaywallKit API and presented as promo offers.
    let winbackOfferCode: String?
    /// User ID used to track referral code distribution. When set, a "Give a friend 7 days free" prompt
    /// appears after a successful purchase.
    let userId: String?
    /// Whether to show the referral prompt after purchase.
    let showReferral: Bool

    @State private var didPurchase = false
    @State private var showingWinback = false
    @State private var referralURL: URL? = nil
    @State private var showingReferral = false

    private let primaryTemplate: PrimaryTemplate
    private let winbackTemplate: WinbackTemplate

    public init(
        appId: String,
        placement: String = "onboarding",
        appName: String = "",
        features: [PaywallFeature] = [],
        products: [PaywallProduct],
        theme: PaywallTheme = PaywallTheme(accent: .blue, accent2: .purple),
        showWinback: Bool = false,
        winbackOfferCode: String? = "winback_7day_free",
        showReferral: Bool = true,
        userId: String? = nil,
        isDismissible: Bool = true,
        termsURL: URL? = URL(string: "https://kreativekoala.llc/terms"),
        privacyURL: URL? = URL(string: "https://kreativekoala.llc/privacy"),
        onPurchase: @escaping (String) async -> Bool,
        onRestore: @escaping () async -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.appId = appId
        self.placement = placement
        self.appName = appName
        self.features = features
        self.products = products
        self.theme = theme
        self.showWinback = showWinback
        self.winbackOfferCode = winbackOfferCode
        self.showReferral = showReferral
        self.userId = userId
        self.isDismissible = isDismissible
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.onPurchase = onPurchase
        self.onRestore = onRestore
        self.onDismiss = onDismiss

        let em = ExperimentManager.shared
        self.primaryTemplate = em.primaryTemplate()
        self.winbackTemplate = em.winbackTemplate()

        // Track impression count for this placement
        em.incrementImpressions(appId: appId)
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
        .interactiveDismissDisabled(!isDismissible && !products.isEmpty)
        .onAppear {
            // Track view event — products may load asynchronously, don't auto-dismiss on empty
            PaywallManager.shared.trackEvent(
                appId: appId, placement: placement,
                templateId: primaryTemplate.rawValue, event: "viewed")
            ExperimentManager.shared.checkServerOverride(appId: appId)
        }
        .sheet(isPresented: $showingReferral) {
            if let url = referralURL {
                ReferralShareView(appName: appName, redemptionURL: url) {
                    showingReferral = false
                    onDismiss()
                }
                .presentationDetents([.medium])
            }
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
        case .trialGate:
            TrialGateTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handlePurchase, onRestore: handleRestore,
                onClose: handleClose, isDismissible: isDismissible)
        case .freeTrialFunnel:
            FreeTrialFunnelTemplate(
                appName: appName, features: features, products: products,
                theme: theme, isDismissible: isDismissible,
                onPurchase: handlePurchase, onRestore: handleRestore,
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
        case .scratchCard:
            WinbackScratchCardTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handleWinbackPurchase,
                onClose: handleWinbackClose)
        case .spinWheel:
            WinbackSpinWheelTemplate(
                appName: appName, features: features, products: products,
                theme: theme, onPurchase: handleWinbackPurchase,
                onClose: handleWinbackClose)
        }
    }

    // MARK: - Handlers

    func handlePurchase(_ productId: String) async -> Bool {
        let success = await onPurchase(productId)
        if success {
            didPurchase = true
            PaywallManager.shared.trackEvent(
                appId: appId, placement: placement,
                templateId: primaryTemplate.rawValue, event: "purchased",
                productId: productId)
            // Track intro offer start separately for conversion attribution
            if let product = products.first(where: { $0.id == productId }),
               let trialDays = product.trialDays, trialDays > 0 {
                PaywallManager.shared.trackEvent(
                    appId: appId, placement: placement,
                    templateId: primaryTemplate.rawValue, event: "intro_offer_started",
                    productId: productId)
            }
            // Show referral share prompt if enabled
            let uid = userId ?? PaywallKitSDK.shared.userId
            if showReferral, !uid.isEmpty {
                if let referral = await PaywallManager.shared.fetchReferralCode(
                    appId: appId, userId: uid, productId: productId) {
                    referralURL = referral.redemptionURL
                    showingReferral = true
                    PaywallKitSDK.shared.markReferralShown()
                } else {
                    onDismiss()
                }
            } else {
                onDismiss()
            }
        }
        return success
    }

    private func handleRestore() {
        PaywallManager.shared.trackEvent(
            appId: appId, placement: placement,
            templateId: primaryTemplate.rawValue, event: "restored")
        Task { await onRestore() }
    }

    private func handleClose() {
        PaywallManager.shared.trackEvent(
            appId: appId, placement: placement,
            templateId: primaryTemplate.rawValue, event: "closed")
        if !didPurchase && showWinback {
            // Always allow transition to winback, even when not dismissible
            PaywallManager.shared.trackEvent(
                appId: appId, placement: "winback",
                templateId: winbackTemplate.rawValue, event: "winback_shown")
            withAnimation(.easeInOut(duration: 0.3)) { showingWinback = true }
        } else if isDismissible {
            // Track dismiss and potentially show Apple offer code sheet
            if !didPurchase {
                StoreManager.shared.trackPaywallDismiss()
            }
            onDismiss()
        }
        // If not dismissible and no winback, do nothing — user must subscribe
    }

    private func handleWinbackPurchase(_ productId: String) {
        Task {
            var success = false
            if let offerCode = winbackOfferCode {
                // Purchase with promotional offer (signed server-side)
                let result = await StoreManager.shared.purchaseWithPromoOffer(
                    productId: productId, offerCode: offerCode)
                if case .purchased = result { success = true }
            } else {
                success = await onPurchase(productId)
            }

            if success {
                PaywallManager.shared.trackEvent(
                    appId: appId, placement: "winback",
                    templateId: winbackTemplate.rawValue, event: "winback_purchased",
                    productId: productId)
            }
        }
    }

    private func handleWinbackClose() {
        guard isDismissible else { return } // Can't dismiss winback when not dismissible
        PaywallManager.shared.trackEvent(
            appId: appId, placement: "winback",
            templateId: winbackTemplate.rawValue, event: "winback_closed")
        // User rejected both paywall AND winback — show Apple offer sheet as last chance
        StoreManager.shared.trackPaywallDismiss()
        onDismiss()
    }
}
