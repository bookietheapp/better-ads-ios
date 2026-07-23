import Foundation
import os

/// Entry point for the Better Ads SDK.
///
/// Host apps configure once, fetch ad models for rendering, and report
/// impression / click events. The SDK owns all networking to the ads backend.
public final class BetterAdsClient: @unchecked Sendable {
    private let api: AdsAPIClient
    private let logger: Logger
    private let analyticsTaskRunner: AnalyticsTaskRunner

    /// Creates a production client backed by `URLSession`.
    public convenience init(configuration: BetterAdsConfiguration) {
        self.init(
            configuration: configuration,
            httpClient: URLSessionHTTPClient(),
            logger: Logger(subsystem: "com.betterads.sdk", category: "BetterAds"),
            analyticsTaskRunner: DefaultAnalyticsTaskRunner()
        )
    }

    /// Internal / test initializer with injectable networking.
    init(
        configuration: BetterAdsConfiguration,
        httpClient: any HTTPClient,
        logger: Logger = Logger(subsystem: "com.betterads.sdk", category: "BetterAds"),
        analyticsTaskRunner: AnalyticsTaskRunner = DefaultAnalyticsTaskRunner()
    ) {
        self.api = AdsAPIClient(configuration: configuration, httpClient: httpClient)
        self.logger = logger
        self.analyticsTaskRunner = analyticsTaskRunner
    }

    /// Fetches ad content for the given placement type.
    public func fetchAd(type: AdType) async throws -> AdModel {
        try await api.fetchAd(type: type)
    }

    /// Reports an impression. Best-effort and non-blocking — never throws to the host.
    public func trackImpression(for adType: AdType) {
        analyticsTaskRunner.run { [api, logger] in
            do {
                try await api.postImpression(type: adType)
            } catch {
                logger.error("Impression tracking failed for \(adType.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Reports a CTA click. Best-effort and non-blocking — never throws to the host.
    public func trackClick(for adType: AdType, ctaValue: String) {
        analyticsTaskRunner.run { [api, logger] in
            do {
                try await api.postClick(type: adType, ctaValue: ctaValue)
            } catch {
                logger.error("Click tracking failed for \(adType.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
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
