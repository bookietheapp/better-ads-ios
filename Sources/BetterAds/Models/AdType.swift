import Foundation

/// Identifies which ad placement to fetch or report analytics for.
///
/// The raw value is used as the `:type` path segment in `/ads/:type`.
public struct AdType: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}
