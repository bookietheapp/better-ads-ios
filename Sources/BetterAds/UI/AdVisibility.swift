import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Bookie impression thresholds (book covers + placement ads).
enum AdImpressionPolicy {
    /// Minimum `visibleArea / totalArea` to count as visible.
    static let minimumVisibleFraction: CGFloat = 0.5
    /// Minimum accumulated time (ms) at ≥ 50% while eligible.
    static let minimumAccumulatedVisibleMs: Double = 200
    /// Pause dwell while estimated **vertical** scroll speed exceeds this (points/sec).
    static let maximumScrollVelocityPointsPerSecond: CGFloat = 1_200
    /// After the first non-zero layout frame, ignore velocity for this long.
    static let velocityWarmupSeconds: TimeInterval = 0.35
}

/// Accumulates Bookie-parity dwell / velocity until one qualification, then latches.
///
/// Velocity is vertical (center Y), matching Bookie's Android book-cover tracker
/// and the impression spec. The tracked target is the whole ad view.
final class AdImpressionVisibilityTracker {
    private(set) var hasQualified = false

    private var accumulatedEligibleMs: Double = 0
    private var lastTickMonotonic: TimeInterval?
    private var lastCenterY: CGFloat?
    private var lastFrameMonotonic: TimeInterval?
    private var velocityWarmupUntil: TimeInterval?

    func reset() {
        hasQualified = false
        accumulatedEligibleMs = 0
        lastTickMonotonic = nil
        lastCenterY = nil
        lastFrameMonotonic = nil
        velocityWarmupUntil = nil
    }

    /// - Returns: `true` once, when the creative has been eligible long enough.
    @discardableResult
    func update(
        visibleFraction: CGFloat,
        frame: CGRect,
        now: TimeInterval,
        appActive: Bool
    ) -> Bool {
        if hasQualified { return false }

        if visibleFraction < AdImpressionPolicy.minimumVisibleFraction {
            accumulatedEligibleMs = 0
            lastTickMonotonic = now
            lastCenterY = nil
            lastFrameMonotonic = nil
            return false
        }

        let deltaTime: TimeInterval
        if let last = lastTickMonotonic {
            deltaTime = min(max(now - last, 0), 0.25)
        } else {
            deltaTime = 1.0 / 60.0
        }
        lastTickMonotonic = now

        let velocity = estimatedVerticalVelocity(centerY: frame.midY, now: now)

        if velocityWarmupUntil == nil, frame.width > 1, frame.height > 1 {
            velocityWarmupUntil = now + AdImpressionPolicy.velocityWarmupSeconds
        }
        let withinWarmup = velocityWarmupUntil.map { now < $0 } ?? false
        let velocityOk = velocity <= AdImpressionPolicy.maximumScrollVelocityPointsPerSecond
        let allowsAccumulation = appActive && !withinWarmup && velocityOk

        if allowsAccumulation {
            accumulatedEligibleMs += deltaTime * 1_000
        }

        lastCenterY = frame.midY
        lastFrameMonotonic = now

        guard accumulatedEligibleMs >= AdImpressionPolicy.minimumAccumulatedVisibleMs else {
            return false
        }
        hasQualified = true
        return true
    }

    private func estimatedVerticalVelocity(centerY: CGFloat, now: TimeInterval) -> CGFloat {
        guard let previousTime = lastFrameMonotonic, let previousY = lastCenterY else {
            return 0
        }
        let dt = now - previousTime
        guard dt > 1e-6 else { return 0 }
        return abs(centerY - previousY) / CGFloat(dt)
    }
}

/// Bookie geometry on the **whole ad view**: `visible = clipped ∩ viewport / unclipped`.
enum AdVisibility {
    static let minimumVisibleFraction: CGFloat = AdImpressionPolicy.minimumVisibleFraction
    /// Collapsed overlays (a few points tall) are not viewable even if fully on screen.
    static let minimumFrameSize: CGFloat = 8

    static func visibleFraction(
        fullItemRect: CGRect,
        clippedItemRect: CGRect,
        viewportRect: CGRect
    ) -> CGFloat {
        guard fullItemRect.width >= minimumFrameSize, fullItemRect.height >= minimumFrameSize,
              viewportRect.width > 0, viewportRect.height > 0 else {
            return 0
        }
        let visible = clippedItemRect.intersection(viewportRect)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return 0 }
        let visibleArea = visible.width * visible.height
        let totalArea = fullItemRect.width * fullItemRect.height
        return CGFloat(visibleArea / totalArea)
    }

    static func visibleFraction(_ frame: CGRect, in viewport: CGRect) -> CGFloat {
        visibleFraction(fullItemRect: frame, clippedItemRect: frame, viewportRect: viewport)
    }

    static func isOnScreen(_ frame: CGRect, in viewport: CGRect) -> Bool {
        visibleFraction(frame, in: viewport) >= minimumVisibleFraction
    }

    static func isOnScreen(
        fullItemRect: CGRect,
        clippedItemRect: CGRect,
        viewportRect: CGRect
    ) -> Bool {
        visibleFraction(
            fullItemRect: fullItemRect,
            clippedItemRect: clippedItemRect,
            viewportRect: viewportRect
        ) >= minimumVisibleFraction
    }

    static func currentViewport() -> CGRect {
        #if canImport(UIKit) && os(iOS)
        if let window = keyWindow() {
            return safeViewport(in: window)
        }
        return UIScreen.main.bounds
        #elseif canImport(AppKit)
        return NSScreen.main?.visibleFrame ?? .zero
        #else
        return .zero
        #endif
    }

    #if canImport(UIKit) && os(iOS)
    static func safeViewport(in window: UIWindow) -> CGRect {
        window.bounds.inset(by: window.safeAreaInsets)
    }

    /// Intersects the unclipped window frame with enclosing scroll views' visible content.
    static func clippedFrame(_ full: CGRect, for view: UIView, in window: UIWindow) -> CGRect {
        guard full.width > 0, full.height > 0 else { return .zero }
        var clipped = full
        var ancestor: UIView? = view.superview
        while let parent = ancestor {
            if let scroll = parent as? UIScrollView {
                let visibleContent = CGRect(
                    x: scroll.contentOffset.x,
                    y: scroll.contentOffset.y,
                    width: scroll.bounds.width,
                    height: scroll.bounds.height
                )
                let visibleInWindow = scroll.convert(visibleContent, to: window)
                guard visibleInWindow.intersects(clipped) else { return .zero }
                clipped = clipped.intersection(visibleInWindow)
                if clipped.isNull || clipped.isEmpty { return .zero }
            }
            if parent === window { break }
            ancestor = parent.superview
        }
        return clipped
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
    #endif
}
