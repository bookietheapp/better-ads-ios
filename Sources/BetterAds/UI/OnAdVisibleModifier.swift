import SwiftUI
import QuartzCore

#if os(iOS)
import UIKit

/// Calls `action` after Bookie-parity viewability: ≥ 50% visible, ≥ 200 ms dwell,
/// calm scroll, app foreground.
///
/// Uses a UIKit probe so visibility works in UIKit-hosted SwiftUI (Bookie lists).
struct OnAdVisibleModifier: ViewModifier {
    var trackingKey: String
    var action: () -> Void

    func body(content: Content) -> some View {
        content.background {
            AdVisibilityProbe(trackingKey: trackingKey, onVisible: action)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct AdVisibilityProbe: UIViewRepresentable {
    var trackingKey: String
    var onVisible: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(trackingKey: trackingKey, onVisible: onVisible)
    }

    func makeUIView(context: Context) -> AdVisibilityProbeView {
        let view = AdVisibilityProbeView()
        view.onVisible = { context.coordinator.onVisible() }
        view.setTrackingKey(context.coordinator.trackingKey)
        return view
    }

    func updateUIView(_ uiView: AdVisibilityProbeView, context: Context) {
        context.coordinator.onVisible = onVisible
        context.coordinator.trackingKey = trackingKey
        uiView.onVisible = { context.coordinator.onVisible() }
        uiView.setTrackingKey(trackingKey)
        uiView.scheduleReport()
    }

    final class Coordinator {
        var trackingKey: String
        var onVisible: () -> Void
        init(trackingKey: String, onVisible: @escaping () -> Void) {
            self.trackingKey = trackingKey
            self.onVisible = onVisible
        }
    }
}

final class AdVisibilityProbeView: UIView {
    var onVisible: (() -> Void)?

    private let tracker = AdImpressionVisibilityTracker()
    private var trackingKey: String?
    private var offsetObservation: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []
    private var lastLoggedVisible: Bool?
    private var reportWorkItem: DispatchWorkItem?
    private var displayLink: CADisplayLink?
    private lazy var displayLinkProxy = DisplayLinkProxy(owner: self)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = false
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        notifications = [
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.report()
            },
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.report()
            },
        ]
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        offsetObservation?.invalidate()
        notifications.forEach { NotificationCenter.default.removeObserver($0) }
        reportWorkItem?.cancel()
        displayLink?.invalidate()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachScrollObserver()
        syncDisplayLink()
        scheduleReport()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        attachScrollObserver()
        scheduleReport()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        report()
    }

    func setTrackingKey(_ key: String) {
        guard trackingKey != key else { return }
        trackingKey = key
        tracker.reset()
        lastLoggedVisible = nil
        syncDisplayLink()
    }

    func scheduleReport() {
        reportWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.attachScrollObserver()
            self?.report()
        }
        reportWorkItem = work
        DispatchQueue.main.async(execute: work)
    }

    private func attachScrollObserver() {
        offsetObservation?.invalidate()
        offsetObservation = nil
        var node: UIView? = superview
        while let current = node {
            if let scroll = current as? UIScrollView {
                offsetObservation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
                    self?.report()
                }
                return
            }
            node = current.superview
        }
    }

    func report() {
        let appActive = UIApplication.shared.applicationState == .active
        guard let window else {
            logIfNeeded(
                visible: false,
                fraction: 0,
                appActive: appActive,
                frame: .zero,
                viewport: .zero
            )
            return
        }
        let full = convert(bounds, to: window)
        let clipped = AdVisibility.clippedFrame(full, for: self, in: window)
        let viewport = AdVisibility.safeViewport(in: window)
        let fraction = AdVisibility.visibleFraction(
            fullItemRect: full,
            clippedItemRect: clipped,
            viewportRect: viewport
        )
        let visible = appActive && fraction >= AdVisibility.minimumVisibleFraction
        let trackingFrame = clipped.isEmpty ? full : clipped
        logIfNeeded(
            visible: visible,
            fraction: fraction,
            appActive: appActive,
            frame: trackingFrame,
            viewport: viewport
        )
        let qualified = tracker.update(
            visibleFraction: fraction,
            frame: trackingFrame,
            now: CACurrentMediaTime(),
            appActive: appActive
        )
        if tracker.hasQualified {
            stopDisplayLink()
        }
        if qualified {
            onVisible?()
        }
    }

    private func syncDisplayLink() {
        if window != nil, !tracker.hasQualified {
            startDisplayLink()
        } else {
            stopDisplayLink()
        }
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: displayLinkProxy, selector: #selector(DisplayLinkProxy.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func logIfNeeded(
        visible: Bool,
        fraction: CGFloat,
        appActive: Bool,
        frame: CGRect,
        viewport: CGRect
    ) {
        guard lastLoggedVisible != visible else { return }
        lastLoggedVisible = visible
        let percent = Int((fraction * 100).rounded())
        AdLog.info(
            "visibility \(visible ? "on" : "off") \(percent)% appActive=\(appActive) " +
                "frame=\(shortRect(frame)) viewport=\(shortRect(viewport))"
        )
    }

    private func shortRect(_ rect: CGRect) -> String {
        String(
            format: "(%.0f,%.0f %.0fx%.0f)",
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height
        )
    }
}

private final class DisplayLinkProxy: NSObject {
    weak var owner: AdVisibilityProbeView?

    init(owner: AdVisibilityProbeView) {
        self.owner = owner
    }

    @objc func tick() {
        owner?.report()
    }
}

#elseif os(macOS)
struct OnAdVisibleModifier: ViewModifier {
    var trackingKey: String
    var action: () -> Void

    func body(content: Content) -> some View {
        content.onAppear(perform: action)
    }
}
#endif

extension View {
    func onAdVisible(trackingKey: String = "", perform action: @escaping () -> Void) -> some View {
        modifier(OnAdVisibleModifier(trackingKey: trackingKey, action: action))
    }
}
