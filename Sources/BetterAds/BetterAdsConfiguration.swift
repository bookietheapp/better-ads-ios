import Foundation

/// Configuration for the Better Ads SDK.
///
/// Identity and locale are injected by the host app — the SDK never reads app globals.
public struct BetterAdsConfiguration: Sendable, Equatable {
    /// Base URL of the dedicated ads backend (e.g. `https://ads.example.com`).
    public let baseURL: URL

    /// Optional API key sent as `X-API-Key`.
    ///
    /// Assumption / open question: simplest auth for new infra. Backend may later
    /// require Bearer tokens, signed requests, or fully anonymous access.
    public let apiKey: String?

    /// Opaque session identifier supplied by the host app.
    public let sessionID: String?

    /// Authenticated user identifier when available; omit for anonymous sessions.
    public let userID: String?

    /// Locale used for localized ad copy (`Accept-Language` + analytics payload).
    public let locale: Locale

    public init(
        baseURL: URL,
        apiKey: String? = nil,
        sessionID: String? = nil,
        userID: String? = nil,
        locale: Locale = .current
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.sessionID = sessionID
        self.userID = userID
        self.locale = locale
    }
}
