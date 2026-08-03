import Foundation

/// SDK-owned ads backend endpoints. Host apps never configure these URLs.
enum BetterAdsEndpoints {
    /// Production Better Ads Cloud Function host for `.serveV1`.
    static let serveV1BaseURL = URL(string: "https://us-central1-better-ads-501813.cloudfunctions.net")!
}
