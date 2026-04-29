import SwiftUI

/// Post-purchase "Give a friend 7 days free" sheet.
/// Call `PaywallManager.shared.fetchReferralCode(appId:userId:productId:)` to get a code,
/// then present this view with the returned URL.
@available(iOS 16.0, *)
public struct ReferralShareView: View {
    let appName: String
    let redemptionURL: URL
    let onDismiss: () -> Void

    @State private var showShareSheet = false

    public init(appName: String, redemptionURL: URL, onDismiss: @escaping () -> Void) {
        self.appName = appName
        self.redemptionURL = redemptionURL
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "gift.fill")
                .font(.system(size: 56))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Give a Friend 7 Days Free")
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Share \(appName) with someone you care about.\nThey get a full week free, no strings attached.")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: { showShareSheet = true }) {
                Label("Share Free Trial", systemImage: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [redemptionURL])
                    .presentationDetents([.medium, .large])
            }

            Button("Maybe later", action: onDismiss)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }
}

// UIActivityViewController wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        // Required on iPad to avoid UIPopoverPresentationController crash
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first {
            vc.popoverPresentationController?.sourceView = window
            vc.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            vc.popoverPresentationController?.permittedArrowDirections = []
        }
        return vc
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
