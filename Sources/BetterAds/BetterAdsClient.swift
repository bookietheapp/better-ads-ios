import Foundation
import os

/// Configured networking client used by `BetterAdView`.
///
/// The SDK owns creative fetch (fixture / remote), analytics POSTs, `device_id`, and `session_id`.
/// Host apps configure once, call ``setUserID(_:)`` on login/logout, and place `BetterAdView`.
public final class BetterAdsClient: @unchecked Sendable {
    private let configuration: BetterAdsConfiguration
    private let api: AdsAPIClient
    private let identity: BetterAdsIdentityStore
    private let eventQueue: AdEventQueue
    private let contentProvider: any BetterAdsContentProviding
    private let contentMode: BetterAdsContentMode
    private let logger: Logger
    private let analyticsTaskRunner: AnalyticsTaskRunner
    private let adCache = AdResponseCache()
    #if os(iOS)
    private var flushCoordinator: AdEventFlushCoordinator?
    #endif

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
        eventStore: AdEventStore? = nil,
        flushScheduler: @escaping AdEventFlushScheduler = { operation in
            Task { await operation() }
        },
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
        let eventQueue = AdEventQueue(
            store: eventStore ?? UserDefaultsAdEventStore(),
            postEvents: { events in
                try await api.postEvents(events)
            },
            scheduleFlush: flushScheduler,
            logger: Logger(subsystem: "com.betterads.sdk", category: "AdEventQueue")
        )
        self.configuration = configuration
        self.identity = identity
        self.api = api
        self.eventQueue = eventQueue
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
        #if os(iOS)
        if configuration.contentMode != .fixture {
            let coordinator = AdEventFlushCoordinator(queue: eventQueue)
            coordinator.start()
            self.flushCoordinator = coordinator
        }
        #endif
    }

    deinit {
        #if os(iOS)
        flushCoordinator?.stop()
        #endif
    }

    /// Updates the account id sent on ads analytics.
    ///
    /// Pass `nil` on logout / guest. When the SDK owns `session_id`, clearing a previous
    /// non-nil user id rotates the session.
    public func setUserID(_ userID: String?) {
        identity.setUserID(userID)
    }

    /// Last successfully fetched creative for `type` + optional keyed id, if any (process memory).
    func cachedAd(for type: AdType, externalAdId: String? = nil) -> AdModel? {
        adCache.ad(for: type, externalAdId: externalAdId)
    }

    /// Fetches ad content for the given placement type / format raw value.
    ///
    /// Pass `externalAdId` for keyed Serve. A keyed 404 / empty result is surfaced as
    /// ``BetterAdsError/unknownAdType(_:)`` — the SDK does **not** retry as unkeyed Serve.
    public func fetchAd(type: AdType, externalAdId: String? = nil) async throws -> AdModel {
        let keyedId = ExternalAdId.normalize(externalAdId)
        do {
            let ad: AdModel
            if let format = AdFormat(rawValue: type.rawValue) {
                ad = try await contentProvider.fetchAd(format: format, externalAdId: keyedId)
            } else {
                ad = try await api.fetchAd(type: type, externalAdId: keyedId)
            }
            adCache.store(ad, for: type, externalAdId: keyedId)
            return ad
        } catch {
            if keyedId != nil, Self.isNoEligibleAd(error) {
                adCache.remove(for: type, externalAdId: keyedId)
            }
            throw error
        }
    }

    /// Fetches ad content for a known format.
    ///
    /// Pass `externalAdId` to request a specific Publisher-owned ad. On keyed miss the
    /// error is returned to the caller — do not fall back to unkeyed `fetchAd`.
    public func fetchAd(format: AdFormat, externalAdId: String? = nil) async throws -> AdModel {
        try await fetchAd(type: AdType(format: format), externalAdId: externalAdId)
    }

    /// Alias for ``fetchAd(format:externalAdId:)``.
    public func requestAd(format: AdFormat, externalAdId: String? = nil) async throws -> AdModel {
        try await fetchAd(format: format, externalAdId: externalAdId)
    }

    private static func isNoEligibleAd(_ error: Error) -> Bool {
        guard let error = error as? BetterAdsError else { return false }
        switch error {
        case .unknownAdType, .httpStatus(code: 404, body: _):
            return true
        default:
            return false
        }
    }

    /// Reports an impression. Best-effort and non-blocking — never throws.
    /// Skipped in fixture mode (no ads analytics backend yet).
    func trackImpression(adId: String) {
        guard contentMode != .fixture else { return }
        guard let adIdInt = AdModel.parsePositiveInt(adId) else {
            logger.warning("Skipping impression — invalid ad_id: \(adId, privacy: .public)")
            return
        }
        analyticsTaskRunner.run { [eventQueue, identity, configuration] in
            let id = identity.snapshot
            let event = AdEvent(
                type: .impression,
                adId: adIdInt,
                deviceId: id.deviceID,
                sessionId: id.sessionID,
                userId: id.userID,
                locale: configuration.locale.identifier
            )
            eventQueue.enqueue(event)
        }
    }

    /// Reports a Design tap. Best-effort and non-blocking — never throws.
    /// Skipped in fixture mode (no ads analytics backend yet).
    func trackClick(adId: String, ctaValue: String) {
        guard contentMode != .fixture else { return }
        guard let adIdInt = AdModel.parsePositiveInt(adId) else {
            logger.warning("Skipping click — invalid ad_id: \(adId, privacy: .public)")
            return
        }
        analyticsTaskRunner.run { [eventQueue, identity, configuration] in
            let id = identity.snapshot
            let event = AdEvent(
                type: .click,
                adId: adIdInt,
                deviceId: id.deviceID,
                sessionId: id.sessionID,
                userId: id.userID,
                locale: configuration.locale.identifier,
                ctaValue: ctaValue
            )
            eventQueue.enqueue(event)
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
