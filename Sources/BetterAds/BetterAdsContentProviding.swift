import Foundation

/// Supplies ad creatives to `BetterAdsClient`.
///
/// Host apps should not implement this — the SDK owns loading. Kept internal for
/// HTTP vs fixture switching and tests.
protocol BetterAdsContentProviding: Sendable {
    func fetchAd(format: AdFormat) async throws -> AdModel
}

struct HTTPBetterAdsContentProvider: BetterAdsContentProviding {
    let api: AdsAPIClient

    func fetchAd(format: AdFormat) async throws -> AdModel {
        try await api.fetchAd(type: AdType(format: format))
    }
}

/// Returns built-in sample creatives (no network) for spike / offline review.
struct FixtureBetterAdsContentProvider: BetterAdsContentProviding {
    func fetchAd(format: AdFormat) async throws -> AdModel {
        if format == .interstitial {
            throw BetterAdsError.unknownAdType(AdType(format: format))
        }
        return .previewFixture(size: format)
    }
}
