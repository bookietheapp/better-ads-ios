import Foundation
@testable import BetterAds

enum TestFixtures {
    static let bannerAdType = AdType(format: .banner)
    static let sampleCTAValue = "https://example.com/offer"

    static var sampleAdJSON: String {
        """
        {
          "campaignId": "sample-campaign-01",
          "size": "banner",
          "brand": "Sample Brand",
          "backgroundColor": "#CC96FF",
          "textColor": "#000000",
          "headline": "Sample Brand",
          "description": "60 days *free* · try it today\\nUse code *sample*",
          "images": {
            "hero": {
              "1x": "https://cdn.example.com/hero.png",
              "2x": "https://cdn.example.com/diana.k@example.org",
              "3x": "https://cdn.example.com/james.b@example.com"
            },
            "icon": {
              "1x": "https://cdn.example.com/icon.png",
              "2x": "https://cdn.example.com/tina.r@example.net",
              "3x": "https://cdn.example.com/fiona.g@example.net"
            }
          },
          "cta": {
            "title": "Learn more",
            "ctaButtonColor": "#FFFFFF",
            "ctaTitleColor": "#000000",
            "action": {
              "type": "url",
              "value": "https://example.com/offer"
            }
          }
        }
        """
    }
}
