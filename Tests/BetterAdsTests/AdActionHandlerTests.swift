import Foundation
import XCTest
@testable import BetterAds

final class AdActionHandlerTests: XCTestCase {
    func testShouldOpenInBrowser_httpAndHttpsOnly() {
        XCTAssertTrue(AdActionHandler.shouldOpenInBrowser(URL(string: "https://example.com")!))
        XCTAssertTrue(AdActionHandler.shouldOpenInBrowser(URL(string: "http://example.com")!))
        XCTAssertFalse(AdActionHandler.shouldOpenInBrowser(URL(string: "bookie://book/9780593638460")!))
        XCTAssertFalse(AdActionHandler.shouldOpenInBrowser(URL(string: "mailto:hi@example.com")!))
    }
}
