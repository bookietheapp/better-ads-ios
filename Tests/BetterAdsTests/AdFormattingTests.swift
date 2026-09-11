import XCTest
@testable import BetterAds

final class AdFormattingTests: XCTestCase {
    func testAspectRatioMatchesTemplateFrame() {
        for format in [AdFormat.compact, .banner, .card] {
            let size = AdLayoutMetrics.templateSize(for: format)
            XCTAssertEqual(
                AdLayoutMetrics.templateAspectRatio(for: format),
                size.width / size.height,
                accuracy: 0.0001,
                "\(format) ratio must track its template frame"
            )
        }
    }

    func testAspectRatioScalesTemplateWidthToWiderScreens() {
        // 430 pt screen with Bookie's 16 pt gutters.
        let contentWidth: CGFloat = 398
        let height = contentWidth / AdLayoutMetrics.templateAspectRatio(for: .banner)
        XCTAssertEqual(height, 189.2, accuracy: 0.1)
    }

    func testInterstitialHasNoDegenerateRatio() {
        XCTAssertEqual(AdLayoutMetrics.templateAspectRatio(for: .interstitial), 1)
    }
}
