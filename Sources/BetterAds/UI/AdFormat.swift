import Foundation

/// Ad creative format / size — NativeOS Template name (`compact` / `banner` / `card`).
///
/// Used as the `size` query on `GET /api/v1/serve`. There is no interstitial template.
public enum AdFormat: String, Hashable, Sendable, Codable, CaseIterable {
    case compact
    case banner
    case card
    /// Kept for source compatibility; Serve has no interstitial and no layout is rendered.
    case interstitial
}
