import Foundation
import os

/// Configured networking client used by `BetterAdView`.
///
/// Host apps create one client, inject it with `.betterAdsClient(_:)`, and place
/// `BetterAdView` where ads should appear. The view owns fetch + analytics.
public final class BetterAdsClient: @unchecked Sendable {
    private let api: AdsAPIClient
    private let contentProvider: any BetterAdsContentProviding
    private let logger: Logger
    private let analyticsTaskRunner: AnalyticsTaskRunner

    /// Creates a production client backed by `URLSession` + `GET /ads/:type`.
    public convenience init(configuration: BetterAdsConfiguration) {
        let httpClient = URLSessionHTTPClient()
        let api = AdsAPIClient(configuration: configuration, httpClient: httpClient)
        self.init(
            configuration: configuration,
            httpClient: httpClient,
            contentProvider: HTTPBetterAdsContentProvider(api: api),
            logger: Logger(subsystem: "com.betterads.sdk", category: "BetterAds"),
            analyticsTaskRunner: DefaultAnalyticsTaskRunner()
        )
    }

    /// Creates a client with a host-provided content source (migration / spike).
    /// Analytics still use the configured ads base URL (`POST …/impressions|clicks`).
    public convenience init(
        configuration: BetterAdsConfiguration,
        contentProvider: any BetterAdsContentProviding
    ) {
        self.init(
            configuration: configuration,
            httpClient: URLSessionHTTPClient(),
            contentProvider: contentProvider,
            logger: Logger(subsystem: "com.betterads.sdk", category: "BetterAds"),
            analyticsTaskRunner: DefaultAnalyticsTaskRunner()
        )
    }

    /// Internal / test initializer with injectable networking.
    init(
        configuration: BetterAdsConfiguration,
        httpClient: any HTTPClient,
        contentProvider: (any BetterAdsContentProviding)? = nil,
        logger: Logger = Logger(subsystem: "com.betterads.sdk", category: "BetterAds"),
        analyticsTaskRunner: AnalyticsTaskRunner = DefaultAnalyticsTaskRunner()
    ) {
        let api = AdsAPIClient(configuration: configuration, httpClient: httpClient)
        self.api = api
        self.contentProvider = contentProvider ?? HTTPBetterAdsContentProvider(api: api)
        self.logger = logger
        self.analyticsTaskRunner = analyticsTaskRunner
    }

    /// Fetches ad content for the given placement type / format raw value.
    public func fetchAd(type: AdType) async throws -> AdModel {
        if let format = AdFormat(rawValue: type.rawValue) {
            return try await contentProvider.fetchAd(format: format)
        }
        return try await api.fetchAd(type: type)
    }

    /// Fetches ad content for a known format.
    public func fetchAd(format: AdFormat) async throws -> AdModel {
        try await contentProvider.fetchAd(format: format)
    }

    /// Reports an impression. Best-effort and non-blocking — never throws.
    func trackImpression(for adType: AdType) {
        analyticsTaskRunner.run { [api, logger] in
            do {
                try await api.postImpression(type: adType)
            } catch {
                logger.error("Impression tracking failed for \(adType.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Reports a CTA click. Best-effort and non-blocking — never throws.
    func trackClick(for adType: AdType, ctaValue: String) {
        analyticsTaskRunner.run { [api, logger] in
            do {
                try await api.postClick(type: adType, ctaValue: ctaValue)
            } catch {
                logger.error("Click tracking failed for \(adType.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }
}

struct HTTPBetterAdsContentProvider: BetterAdsContentProviding {
    let api: AdsAPIClient

    func fetchAd(format: AdFormat) async throws -> AdModel {
        try await api.fetchAd(type: AdType(format: format))
    }
}

/// Abstracts unstructured task creation so analytics can be awaited in tests.
protocol AnalyticsTaskRunner: Sendable {
    func run(_ operation: @escaping @Sendable () async -> Void)
}

struct DefaultAnalyticsTaskRunner: AnalyticsTaskRunner {
    func run(_ operation: @escaping @Sendable () async -> Void) {
        Task {
            await operation()
        }
    }
}
