import XCTest
@testable import BetterAds

final class AdVisibilityTests: XCTestCase {
    private let viewport = CGRect(x: 0, y: 0, width: 390, height: 844)
    private let bannerSize = CGSize(width: 345, height: 164)

    func testFullyOnScreen_isVisible() {
        let frame = CGRect(origin: CGPoint(x: 22, y: 200), size: bannerSize)
        XCTAssertTrue(AdVisibility.isOnScreen(frame, in: viewport))
    }

    func testFullyBelowFold_isNotVisible() {
        let frame = CGRect(origin: CGPoint(x: 22, y: 900), size: bannerSize)
        XCTAssertFalse(AdVisibility.isOnScreen(frame, in: viewport))
    }

    func testExactlyHalfVisible_isVisible() {
        // 82 of 164 height on screen = 50%.
        let frame = CGRect(origin: CGPoint(x: 22, y: 762), size: bannerSize)
        XCTAssertTrue(AdVisibility.isOnScreen(frame, in: viewport))
    }

    func testJustUnderHalfVisible_isNotVisible() {
        let frame = CGRect(origin: CGPoint(x: 22, y: 763), size: bannerSize)
        XCTAssertFalse(AdVisibility.isOnScreen(frame, in: viewport))
    }

    func testZeroSize_isNotVisible() {
        XCTAssertFalse(AdVisibility.isOnScreen(.zero, in: viewport))
        XCTAssertFalse(AdVisibility.isOnScreen(CGRect(x: 0, y: 0, width: 345, height: 164), in: .zero))
    }

    func testCollapsedSliver_isNotVisible() {
        let sliver = CGRect(x: 22, y: 200, width: 345, height: 3)
        XCTAssertFalse(AdVisibility.isOnScreen(sliver, in: viewport))
    }

    func testClippedAgainstSafeViewport_usesUnclippedAreaAsDenominator() {
        let full = CGRect(x: 0, y: 100, width: 100, height: 200)
        let clipped = CGRect(x: 0, y: 100, width: 100, height: 50)
        let safeViewport = CGRect(x: 0, y: 80, width: 390, height: 720)
        XCTAssertFalse(
            AdVisibility.isOnScreen(
                fullItemRect: full,
                clippedItemRect: clipped,
                viewportRect: safeViewport
            )
        )
        let halfClipped = CGRect(x: 0, y: 100, width: 100, height: 100)
        XCTAssertTrue(
            AdVisibility.isOnScreen(
                fullItemRect: full,
                clippedItemRect: halfClipped,
                viewportRect: safeViewport
            )
        )
    }

    func testTracker_qualifiesAfterDwellOnceWarmupEnds() {
        let tracker = AdImpressionVisibilityTracker()
        let frame = CGRect(origin: CGPoint(x: 22, y: 200), size: bannerSize)
        let t0: TimeInterval = 10

        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0, appActive: true))
        XCTAssertFalse(
            tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.34, appActive: true)
        )
        XCTAssertTrue(
            tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.56, appActive: true)
        )
        XCTAssertFalse(
            tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.90, appActive: true)
        )
    }

    func testTracker_resetsDwellWhenVisibilityDrops() {
        let tracker = AdImpressionVisibilityTracker()
        let frame = CGRect(origin: CGPoint(x: 22, y: 200), size: bannerSize)
        let t0: TimeInterval = 10

        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0, appActive: true))
        XCTAssertFalse(tracker.update(visibleFraction: 0.2, frame: frame, now: t0 + 0.40, appActive: true))
        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.41, appActive: true))
        XCTAssertTrue(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.62, appActive: true))
    }

    func testTracker_resetAllowsSecondQualification() {
        let tracker = AdImpressionVisibilityTracker()
        let frame = CGRect(origin: CGPoint(x: 22, y: 200), size: bannerSize)
        let t0: TimeInterval = 10

        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0, appActive: true))
        XCTAssertTrue(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.56, appActive: true))
        tracker.reset()
        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.57, appActive: true))
        XCTAssertTrue(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 1.13, appActive: true))
    }

    func testTracker_fastVerticalScrollPausesDwell() {
        let tracker = AdImpressionVisibilityTracker()
        let t0: TimeInterval = 10
        var frame = CGRect(origin: CGPoint(x: 22, y: 200), size: bannerSize)

        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0, appActive: true))
        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.34, appActive: true))
        frame.origin.y = 500
        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.36, appActive: true))
        XCTAssertFalse(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.50, appActive: true))
        XCTAssertTrue(tracker.update(visibleFraction: 1, frame: frame, now: t0 + 0.58, appActive: true))
    }
}
