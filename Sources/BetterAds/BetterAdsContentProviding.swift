import Foundation

/// Supplies ad creatives to `BetterAdsClient`.
///
/// The default client uses the dedicated ads HTTP API (`GET /ads/:type`).
/// Host apps may inject a provider during migration (e.g. Bookie's existing `getAd`).
public protocol BetterAdsContentProviding: Sendable {
    func fetchAd(format: AdFormat) async throws -> AdModel
}
