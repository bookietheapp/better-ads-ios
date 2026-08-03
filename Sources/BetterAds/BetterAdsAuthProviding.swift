import Foundation

/// Supplies auth for SDK-owned network calls (e.g. Bookie `getAd` Bearer token).
///
/// The host injects this; the SDK never reads Firebase / app auth globals.
public protocol BetterAdsAuthProviding: Sendable {
    /// Returns a raw access token (without the `Bearer ` prefix), or `nil` if unauthenticated.
    func bearerAccessToken() async -> String?
}
