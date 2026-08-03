import Foundation

/// Where the SDK loads creatives from until the dedicated ads backend ships.
public enum BetterAdsContentMode: String, Sendable, Equatable {
    /// Offline / spike: returns built-in sample creatives (no network).
    case fixture
    /// Interim: `GET /getAd?size={format}` (legacy Bookie Cloud Function shape).
    case bookieGetAd
    /// Current ads backend: `GET /api/v1/serve?size={format}` (+ optional `app=` while unauthenticated).
    case serveV1
    /// Future dedicated ads API: `GET /ads/{format}`.
    case dedicatedAPI
}

/// Configuration for the Better Ads SDK.
///
/// ``serveV1`` owns its fetch URL inside the SDK — hosts never pass a base URL for that mode.
/// ``baseURL`` is only for legacy `.bookieGetAd` / `.dedicatedAPI`.
/// ``apiKey`` is sent as `X-API-Key` when non-empty (optional today; required once the backend enforces auth).
///
/// Identity defaults (recommended):
/// - omit ``deviceID`` → SDK persists an install UUID
/// - omit ``sessionID`` → SDK generates / rotates session on logout via ``BetterAdsClient/setUserID(_:)``
/// - set ``userID`` when logged in, or call ``BetterAdsClient/setUserID(_:)`` later
public struct BetterAdsConfiguration: Sendable, Equatable {
    /// Host-issued Better Ads API key (`X-API-Key` on remote calls). Empty until the backend requires it.
    public let apiKey: String

    /// Legacy remote base URL for `.bookieGetAd` / `.dedicatedAPI`. Ignored for `.serveV1` / `.fixture`.
    public let baseURL: URL?

    /// How creatives are loaded. Defaults to `.fixture` while the ads backend is in development.
    public let contentMode: BetterAdsContentMode

    /// Transitional app identifier for `.serveV1` (`app` query). Omit once the API key identifies the host.
    public let appName: String?

    /// Optional override. When `nil`, the SDK owns session id lifecycle.
    public let sessionID: String?

    /// Initial authenticated user id; omit when logged out. Prefer ``BetterAdsClient/setUserID(_:)`` for updates.
    public let userID: String?

    /// Optional override. When `nil`, the SDK persists an install-scoped device id.
    public let deviceID: String?

    /// Locale used for localized ad copy (`Accept-Language` + analytics payload).
    public let locale: Locale

    public init(
        apiKey: String = "",
        contentMode: BetterAdsContentMode = .fixture,
        baseURL: URL? = nil,
        appName: String? = nil,
        sessionID: String? = nil,
        userID: String? = nil,
        deviceID: String? = nil,
        locale: Locale = .current
    ) {
        self.apiKey = apiKey
        self.contentMode = contentMode
        self.baseURL = baseURL
        self.appName = appName
        self.sessionID = sessionID
        self.userID = userID
        self.deviceID = deviceID
        self.locale = locale
    }

    /// Resolved HTTP base URL for the active content mode.
    var resolvedBaseURL: URL? {
        switch contentMode {
        case .serveV1:
            return BetterAdsEndpoints.serveV1BaseURL
        case .bookieGetAd, .dedicatedAPI:
            return baseURL
        case .fixture:
            return nil
        }
    }

    /// Spike helper: fixture creatives configured with the host API key.
    public static func fixture(
        apiKey: String,
        userID: String? = nil,
        locale: Locale = .current
    ) -> BetterAdsConfiguration {
        BetterAdsConfiguration(
            apiKey: apiKey,
            contentMode: .fixture,
            userID: userID,
            locale: locale
        )
    }
}
