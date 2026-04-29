import SwiftUI

/// Attach to your root view to automatically show the referral prompt
/// to existing subscribers after launch.
///
/// Usage:
/// ```swift
/// ContentView()
///     .paywallKitReferral()
/// ```
///
/// Requires `PaywallKit.configure(...)` to have been called first.
private struct ReferralItem: Identifiable {
    let id = UUID()
    let url: URL
}

@available(iOS 16.0, *)
struct ReferralViewModifier: ViewModifier {
    @State private var referralItem: ReferralItem? = nil
    @State private var didRun = false
    @ObservedObject private var store = StoreManager.shared

    func body(content: Content) -> some View {
        content
            .onAppear { checkAndFetch() }
            .onChange(of: store.isPremium) { isPremium in
                if isPremium { checkAndFetch() }
            }
            .sheet(item: $referralItem) { item in
                ReferralShareView(
                    appName: PaywallKitSDK.shared.appName,
                    redemptionURL: item.url
                ) { referralItem = nil }
                .presentationDetents([.medium])
            }
    }

    private func checkAndFetch() {
        guard !didRun,
              PaywallKitSDK.shared.isReferralPromptDue() else { return }
        didRun = true
        Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard StoreManager.shared.isPremium else {
                didRun = false
                return
            }
            if let referral = await PaywallManager.shared.fetchReferralCode(
                appId: PaywallKitSDK.shared.appId,
                userId: PaywallKitSDK.shared.userId
            ) {
                await MainActor.run {
                    referralItem = ReferralItem(url: referral.redemptionURL)
                    PaywallKitSDK.shared.markReferralShown()
                }
            }
        }
    }
}

@available(iOS 16.0, *)
public extension View {
    /// Automatically shows a "Give a friend 7 days free" sheet to existing subscribers.
    /// Call `PaywallKit.configure(...)` before attaching this modifier.
    func paywallKitReferral() -> some View {
        modifier(ReferralViewModifier())
    }
}
