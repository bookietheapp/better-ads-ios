import Foundation
@testable import BetterAds

enum TestFixtures {
    static let bannerAdType = AdType(format: .banner)
    static let sampleCTAValue = "https://example.com/offer"

    static var sampleAdJSON: String {
        """
        {
          "adId": "42",
          "campaignId": "10",
          "size": "banner",
          "images": {
            "hero": {
              "1x": "https://cdn.example.com/hero.png",
              "2x": "https://cdn.example.com/diana.k@example.org",
              "3x": "https://cdn.example.com/james.b@example.com"
            }
          },
          "ctaLink": "https://example.com/offer"
        }
        """
    }
}
