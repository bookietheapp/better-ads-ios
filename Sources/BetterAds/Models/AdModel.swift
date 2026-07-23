import Foundation

/// Ad content returned by `GET /ads/:type`.
public struct AdModel: Hashable, Sendable, Codable, Equatable {
    public let type: AdType
    public let brand: String
    public let images: AdImages
    public let headline: String
    public let description: String
    public let cta: AdCTA

    public init(
        type: AdType,
        brand: String,
        images: AdImages,
        headline: String,
        description: String,
        cta: AdCTA
    ) {
        self.type = type
        self.brand = brand
        self.images = images
        self.headline = headline
        self.description = description
        self.cta = cta
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

/// Signed image URLs at 1x / 2x / 3x scale factors.
public struct AdImageURLs: Hashable, Sendable, Codable, Equatable {
    public let url1x: URL
    public let url2x: URL
    public let url3x: URL

    public init(url1x: URL, url2x: URL, url3x: URL) {
        self.url1x = url1x
        self.url2x = url2x
        self.url3x = url3x
    }

    private enum CodingKeys: String, CodingKey {
        case url1x = "1x"
        case url2x = "2x"
        case url3x = "3x"
    }
}

public struct AdCTA: Hashable, Sendable, Codable, Equatable {
    public let title: String
    public let action: AdCTAAction

    public init(title: String, action: AdCTAAction) {
        self.title = title
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
}
