import Foundation

/// Identifies which ad to fetch — the `:type` path segment in `/ads/:type`.
///
/// For Bookie placement parity, pass the format raw value
/// (`AdFormat.compact.rawValue`, `.banner`, `.card`).
public struct AdType: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(format: AdFormat) {
        self.rawValue = format.rawValue
    }

    public var description: String { rawValue }
}
