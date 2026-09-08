import CoreGraphics
import Foundation

/// Slim Serve Design payload: one hero image plus a tap destination.
///
/// NativeOS does not compose copy, colors, logo, or a CTA button. The SDK
/// renders `images.hero` at the Template 1x frame and opens `ctaLink` on tap.
public struct AdModel: Hashable, Sendable, Codable, Equatable {
    public let adId: String
    public let campaignId: String
    public let size: String
    public let images: AdImages
    public let ctaLink: String

    public init(
        adId: String,
        campaignId: String,
        size: String,
        images: AdImages,
        ctaLink: String
    ) {
        self.adId = adId
        self.campaignId = campaignId
        self.size = size
        self.images = images
        self.ctaLink = ctaLink
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        adId = try Self.decodeIDString(container, forKey: .adId, required: true)
        campaignId = (try? Self.decodeIDString(container, forKey: .campaignId, required: false)) ?? ""
        size = try container.decode(String.self, forKey: .size)
        images = try container.decode(AdImages.self, forKey: .images)
        ctaLink = try container.decode(String.self, forKey: .ctaLink)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(adId, forKey: .adId)
        try container.encode(campaignId, forKey: .campaignId)
        try container.encode(size, forKey: .size)
        try container.encode(images, forKey: .images)
        try container.encode(ctaLink, forKey: .ctaLink)
    }

    /// Resolved format from the `size` field when recognized.
    public var format: AdFormat? {
        AdFormat(rawValue: size)
    }

    /// CTA destination inferred from `ctaLink` (https → `.url`, otherwise `.deeplink`).
    public var ctaAction: AdCTAAction {
        AdCTAAction.from(ctaLink: ctaLink)
    }

    /// Parses Serve `adId` for analytics. Returns `nil` when not a positive integer.
    public var adIdAsInt: Int? {
        Self.parsePositiveInt(adId)
    }

    private enum CodingKeys: String, CodingKey {
        case adId, campaignId, size, images, ctaLink
    }

    private static func decodeIDString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys,
        required: Bool
    ) throws -> String {
        if let string = try? container.decode(String.self, forKey: key) {
            return string
        }
        if let int = try? container.decode(Int.self, forKey: key) {
            return String(int)
        }
        if required {
            throw DecodingError.keyNotFound(
                key,
                .init(codingPath: container.codingPath, debugDescription: "Missing \(key.stringValue)")
            )
        }
        return ""
    }

    static func parsePositiveInt(_ raw: String) -> Int? {
        guard let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              value > 0
        else {
            return nil
        }
        return value
    }
}

public struct AdImages: Hashable, Sendable, Codable, Equatable {
    public let hero: AdImageURLs

    public init(hero: AdImageURLs) {
        self.hero = hero
    }
}

/// Signed image URL strings at 1x / 2x / 3x.
///
/// All three densities are always present on Serve. Pick the matching scale;
/// do not substitute another density.
public struct AdImageURLs: Hashable, Sendable, Codable, Equatable {
    public let oneX: String
    public let twoX: String
    public let threeX: String

    public init(oneX: String, twoX: String, threeX: String) {
        self.oneX = oneX
        self.twoX = twoX
        self.threeX = threeX
    }

    private enum CodingKeys: String, CodingKey {
        case oneX = "1x"
        case twoX = "2x"
        case threeX = "3x"
    }

    /// Picks the matching asset for the given display scale.
    public func url(for scale: CGFloat) -> URL? {
        let urlString: String
        if scale >= 3 {
            urlString = threeX
        } else if scale >= 2 {
            urlString = twoX
        } else {
            urlString = oneX
        }
        guard !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
}

public struct AdCTAAction: Hashable, Sendable, Codable, Equatable {
    public enum ActionType: String, Hashable, Sendable, Codable {
        case url
        case deeplink
    }

    public let type: ActionType
    public let value: String

    public init(type: ActionType, value: String) {
        self.type = type
        self.value = value
    }

    /// Maps Serve `ctaLink` to a navigation action.
    public static func from(ctaLink: String) -> AdCTAAction {
        let trimmed = ctaLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return AdCTAAction(type: .deeplink, value: trimmed)
        }
        return AdCTAAction(type: .url, value: trimmed)
    }
}

extension AdModel {
    /// Neutral preview fixture for SwiftUI layout review (no real advertiser).
    public static let previewFixture = AdModel.previewFixture(size: .banner)

    public static func previewFixture(size: AdFormat) -> AdModel {
        AdModel(
            adId: "1",
            campaignId: "1",
            size: size.rawValue,
            images: AdImages(hero: heroURLs(for: size)),
            ctaLink: "https://example.com/offer"
        )
    }

    private static func heroURLs(for size: AdFormat) -> AdImageURLs {
        switch size {
        case .compact:
            return AdImageURLs(
                oneX: "https://picsum.photos/329/51",
                twoX: "https://picsum.photos/658/102",
                threeX: "https://picsum.photos/987/153"
            )
        case .banner:
            return AdImageURLs(
                oneX: "https://picsum.photos/345/164",
                twoX: "https://picsum.photos/690/328",
                threeX: "https://picsum.photos/1035/492"
            )
        case .card:
            return AdImageURLs(
                oneX: "https://picsum.photos/336/443",
                twoX: "https://picsum.photos/672/886",
                threeX: "https://picsum.photos/1008/1329"
            )
        case .interstitial:
            return AdImageURLs(oneX: "", twoX: "", threeX: "")
        }
    }
}
