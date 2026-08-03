import Foundation
import os

/// Configured networking client used by `BetterAdView`.
///
/// The SDK owns creative fetch (fixture / remote), analytics POSTs, `device_id`, and `session_id`.
/// Host apps configure once, call ``setUserID(_:)`` on login/logout, and place `BetterAdView`.
public final class BetterAdsClient: @unchecked Sendable {
    private let api: AdsAPIClient
    private let identity: BetterAdsIdentityStore
    private let contentProvider: any BetterAdsContentProviding
    private let contentMode: BetterAdsContentMode
    private let logger: Logger
    private let analyticsTaskRunner: AnalyticsTaskRunner
    private let adCache = AdResponseCache()

    /// Spike-friendly client with built-in sample creatives (no base URL).
    public static func fixture(
        apiKey: String,
        userID: String? = nil,
        locale: Locale = .current
    ) -> BetterAdsClient {
        BetterAdsClient(
            configuration: .fixture(apiKey: apiKey, userID: userID, locale: locale)
        )
    }

    /// Creates a client. Creative source is `configuration.contentMode`.
    ///
    /// Pass `authProvider` only for remote modes that need a Bearer token.
    public convenience init(
        configuration: BetterAdsConfiguration,
        authProvider: (any BetterAdsAuthProviding)? = nil
    ) {
        let httpClient = URLSessionHTTPClient()
        self.init(
            configuration: configuration,
            httpClient: httpClient,
            authProvider: authProvider,
            contentProvider: nil,
            logger: Logger(subsystem: "com.betterads.sdk", category: "BetterAds"),
            analyticsTaskRunner: DefaultAnalyticsTaskRunner()
        )
    }

    /// Internal / test initializer with injectable networking.
    init(
        configuration: BetterAdsConfiguration,
        httpClient: any HTTPClient,
        authProvider: (any BetterAdsAuthProviding)? = nil,
        contentProvider: (any BetterAdsContentProviding)? = nil,
        logger: Logger = Logger(subsystem: "com.betterads.sdk", category: "BetterAds"),
        analyticsTaskRunner: AnalyticsTaskRunner = DefaultAnalyticsTaskRunner()
    ) {
        let identity = BetterAdsIdentityStore(
            deviceID: configuration.deviceID,
            sessionID: configuration.sessionID,
            userID: configuration.userID
        )
        let api = AdsAPIClient(
            configuration: configuration,
            identity: identity,
            httpClient: httpClient,
            authProvider: authProvider
        )
        self.identity = identity
        self.api = api
        self.contentMode = configuration.contentMode
        if let contentProvider {
            self.contentProvider = contentProvider
        } else {
            switch configuration.contentMode {
            case .fixture:
                self.contentProvider = FixtureBetterAdsContentProvider()
            case .bookieGetAd, .serveV1, .dedicatedAPI:
                self.contentProvider = HTTPBetterAdsContentProvider(api: api)
            }
        }
        self.logger = logger
        self.analyticsTaskRunner = analyticsTaskRunner
    }

    /// Updates the account id sent on ads analytics.
    ///
    /// Pass `nil` on logout / guest. When the SDK owns `session_id`, clearing a previous
    /// non-nil user id rotates the session.
    public func setUserID(_ userID: String?) {
        identity.setUserID(userID)
    }

    /// Last successfully fetched creative for `type`, if any (process memory).
    func cachedAd(for type: AdType) -> AdModel? {
        adCache.ad(for: type)
    }

    /// Fetches ad content for the given placement type / format raw value.
    public func fetchAd(type: AdType) async throws -> AdModel {
        let ad: AdModel
        if let format = AdFormat(rawValue: type.rawValue) {
            ad = try await contentProvider.fetchAd(format: format)
        } else {
            ad = try await api.fetchAd(type: type)
        }
        adCache.store(ad, for: type)
        return ad
    }

    /// Fetches ad content for a known format.
    public func fetchAd(format: AdFormat) async throws -> AdModel {
        try await fetchAd(type: AdType(format: format))
    }

    /// Reports an impression. Best-effort and non-blocking — never throws.
    /// Skipped in fixture mode (no ads analytics backend yet).
    func trackImpression(for adType: AdType) {
        guard contentMode != .fixture else { return }
        analyticsTaskRunner.run { [api, logger] in
            do {
                try await api.postImpression(type: adType)
            } catch {
                logger.error("Impression tracking failed for \(adType.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Reports a CTA click. Best-effort and non-blocking — never throws.
    /// Skipped in fixture mode (no ads analytics backend yet).
    func trackClick(for adType: AdType, ctaValue: String) {
        guard contentMode != .fixture else { return }
        analyticsTaskRunner.run { [api, logger] in
            do {
                try await api.postClick(type: adType, ctaValue: ctaValue)
            } catch {
                logger.error("Click tracking failed for \(adType.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
    }
}

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
