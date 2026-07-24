import Foundation

/// Ad creative format / size.
///
/// Matches Bookie iOS `PlacementAdSize` (`compact` / `banner` / `card` / `interstitial`).
/// Used as the `:type` path segment for `GET /ads/:type` and analytics routes.
public enum AdFormat: String, Hashable, Sendable, Codable, CaseIterable {
    case compact
    case banner
    case card
    /// Modeled for API parity with Bookie; no SDK layout is rendered.
    case interstitial
}
