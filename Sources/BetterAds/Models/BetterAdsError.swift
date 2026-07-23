import Foundation

/// Typed errors thrown by ad fetch operations.
///
/// Analytics tracking never throws — failures are logged and swallowed.
public enum BetterAdsError: Error, Equatable, Sendable {
    case invalidBaseURL
    case invalidResponse
    case httpStatus(code: Int, body: String?)
    case decodingFailed(String)
    case transport(String)
    case unknownAdType(AdType)

    public var localizedDescription: String {
        switch self {
        case .invalidBaseURL:
            return "BetterAds base URL is invalid."
        case .invalidResponse:
            return "BetterAds received an invalid HTTP response."
        case let .httpStatus(code, body):
            if let body, !body.isEmpty {
                return "BetterAds request failed with status \(code): \(body)"
            }
            return "BetterAds request failed with status \(code)."
        case let .decodingFailed(detail):
            return "BetterAds failed to decode response: \(detail)"
        case let .transport(detail):
            return "BetterAds transport error: \(detail)"
        case let .unknownAdType(type):
            return "BetterAds unknown ad type: \(type.rawValue)"
        }
    }
}
