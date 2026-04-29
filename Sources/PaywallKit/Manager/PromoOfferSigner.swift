import Foundation
import StoreKit

/// Fetches a promo offer signature from the PaywallKit API backend,
/// then returns a `Product.PurchaseOption` ready for `product.purchase(options:)`.
@available(iOS 15.0, macOS 12.0, *)
public enum PromoOfferSigner {

    struct SignResponse: Decodable {
        let keyIdentifier: String
        let nonce: String
        let timestamp: Int
        let signature: String
    }

    /// Returns a promotional offer purchase option for `product.purchase(options:)`.
    /// Calls `POST /sign-promo` on the PaywallKit API.
    public static func purchaseOption(
        product: Product,
        offerCode: String,
        applicationUsername: String = "",
        bundleId: String = Bundle.main.bundleIdentifier ?? ""
    ) async throws -> Product.PurchaseOption {
        let apiBase = await MainActor.run { PaywallManager.shared.apiBase }
        guard let url = URL(string: "\(apiBase)/sign-promo") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "bundleId": bundleId,
            "productId": product.id,
            "offerCode": offerCode,
            "applicationUsername": applicationUsername,
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        let resp = try JSONDecoder().decode(SignResponse.self, from: data)

        guard let nonce = UUID(uuidString: resp.nonce),
              let sigData = Data(base64Encoded: resp.signature) else {
            throw URLError(.cannotParseResponse)  // not a throwing call site; guarded manually
        }

        return Product.PurchaseOption.promotionalOffer(
            offerID: offerCode,
            keyID: resp.keyIdentifier,
            nonce: nonce,
            signature: sigData,
            timestamp: resp.timestamp
        )
    }
}
