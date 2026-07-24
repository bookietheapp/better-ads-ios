import CoreGraphics
import Foundation

/// Ad creative payload.
///
/// Field set mirrors Bookie `PlacementAdResponse` so layouts can stay pixel-aligned
/// with the in-app placement ads.
public struct AdModel: Hashable, Sendable, Codable, Equatable {
    public let campaignId: String
    public let size: String
    public let brand: String
    public let backgroundColor: String
    public let textColor: String
    public let headline: String
    public let description: String
    public let images: AdImages
    public let cta: AdCTA

    public init(
        campaignId: String,
        size: String,
        brand: String,
        backgroundColor: String,
        textColor: String,
        headline: String,
        description: String,
        images: AdImages,
        cta: AdCTA
    ) {
        self.campaignId = campaignId
        self.size = size
        self.brand = brand
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.headline = headline
        self.description = description
        self.images = images
        self.cta = cta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        campaignId = try container.decodeIfPresent(String.self, forKey: .campaignId) ?? ""
        size = try container.decode(String.self, forKey: .size)
        brand = try container.decode(String.self, forKey: .brand)
        backgroundColor = try container.decode(String.self, forKey: .backgroundColor)
        textColor = try container.decode(String.self, forKey: .textColor)
        headline = try container.decode(String.self, forKey: .headline)
        description = try container.decode(String.self, forKey: .description)
        images = try container.decode(AdImages.self, forKey: .images)
        cta = try container.decode(AdCTA.self, forKey: .cta)
    }

    /// Resolved format from the `size` field when recognized.
    public var format: AdFormat? {
        AdFormat(rawValue: size)
    }
}

public struct AdImages: Hashable, Sendable, Codable, Equatable {
    public let hero: AdImageURLs
    public let icon: AdImageURLs

    public init(hero: AdImageURLs, icon: AdImageURLs) {
        self.hero = hero
        self.icon = icon
    }
}

/// Signed image URL strings at 1x / 2x / 3x (same shape as Bookie `PlacementAdImageSet`).
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

    /// Picks the closest asset for the given display scale (Bookie parity).
    public func url(for scale: CGFloat) -> URL? {
        let urlString: String
        if scale >= 3, !threeX.isEmpty {
            urlString = threeX
        } else if scale >= 2, !twoX.isEmpty {
            urlString = twoX
        } else if !oneX.isEmpty {
            urlString = oneX
        } else if !twoX.isEmpty {
            urlString = twoX
        } else if !threeX.isEmpty {
            urlString = threeX
        } else {
            return nil
        }
        return URL(string: urlString)
    }
}

public struct AdCTA: Hashable, Sendable, Codable, Equatable {
    public let title: String
    public let ctaButtonColor: String
    public let ctaTitleColor: String
    public let action: AdCTAAction

    public init(
        title: String,
        ctaButtonColor: String,
        ctaTitleColor: String,
        action: AdCTAAction
    ) {
        self.title = title
        self.ctaButtonColor = ctaButtonColor
        self.ctaTitleColor = ctaTitleColor
        self.action = action
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawType = try container.decode(String.self, forKey: .type)
        type = ActionType(rawValue: rawType) ?? .url
        value = try container.decode(String.self, forKey: .value)
    }
}

extension AdModel {
    /// Neutral preview fixture for SwiftUI layout review (no real advertiser).
    public static let previewFixture = AdModel(
        campaignId: "sample-campaign-01",
        size: "banner",
        brand: "Sample Brand",
        backgroundColor: "#CC96FF",
        textColor: "#000000",
        headline: "Sample Brand",
        description: "60 days *free* · try it today\nUse code *sample*",
        images: AdImages(
            hero: AdImageURLs(
                oneX: "https://picsum.photos/205/164",
                twoX: "https://picsum.photos/410/328",
                threeX: "https://picsum.photos/615/492"
            ),
            icon: AdImageURLs(
                oneX: "https://picsum.photos/109/17",
                twoX: "https://picsum.photos/218/34",
                threeX: "https://picsum.photos/327/51"
            )
        ),
        cta: AdCTA(
            title: "Learn more",
            ctaButtonColor: "#FFFFFF",
            ctaTitleColor: "#000000",
            action: AdCTAAction(type: .url, value: "https://example.com/offer")
        )
    )

    public static func previewFixture(size: AdFormat) -> AdModel {
        AdModel(
            campaignId: previewFixture.campaignId,
            size: size.rawValue,
            brand: previewFixture.brand,
            backgroundColor: previewFixture.backgroundColor,
            textColor: previewFixture.textColor,
            headline: previewFixture.headline,
            description: previewFixture.description,
            images: previewFixture.images,
            cta: previewFixture.cta
        )
    }
}
