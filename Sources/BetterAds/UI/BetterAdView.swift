import SwiftUI

/// Ready-to-display ad view for a Bookie-parity format (`compact` / `banner` / `card`).
///
/// Lifecycle (all owned by the SDK — hosts only place this view):
/// - Loads from Serve on first display (or from the in-memory cache on remount).
/// - Revalidates only when the host screen session changes (pull-to-refresh / new visit).
/// - Scrolling the slot off and back does **not** refetch or show the skeleton again.
/// - Keeps the current creative on screen while a session revalidate is in flight.
///
/// The SDK fetches, renders the hero image, tracks impression/click, and opens `ctaLink`.
/// Host callbacks are observation-only (e.g. Firebase bridge) — they do not own navigation.
public struct BetterAdView: View {
    private let format: AdFormat
    private let externalAdId: String?
    private let explicitClient: BetterAdsClient?
    private let onClick: ((AdCTAAction) -> Void)?
    private let onImpression: ((AdModel) -> Void)?
    private let onAvailabilityChanged: ((Bool) -> Void)?
    /// Optional screen-session token. Changing it on a still-mounted view re-arms
    /// that placement. Per-row UUIDs are ignored for counting.
    private let impressionSessionID: String?

    @Environment(\.betterAdsClient) private var environmentClient

    /// Creates an ad view that reads `BetterAdsClient` from the environment.
    ///
    /// - Parameters:
    ///   - externalAdId: Publisher-owned id for keyed Serve. Omit for the unkeyed pool.
    ///     A keyed miss renders nothing and reports `onAvailabilityChanged(false)` —
    ///     it does **not** fall back to unkeyed Serve.
    ///   - onImpression: Optional host observation after the SDK records an impression.
    ///   - onClick: Optional host observation after the SDK records a click and opens `ctaLink`.
    ///   - impressionSessionID: Optional screen-session token. The SDK already
    ///     counts at most once per placement + ad id across list recycle.
    ///     Changing this on a still-mounted view re-arms that placement.
    ///     Per-row UUIDs are ignored for counting. To re-arm after rows were
    ///     disposed, call ``BetterAdsClient/resetImpressionSession()``.
    public init(
        format: AdFormat,
        externalAdId: String? = nil,
        onImpression: ((AdModel) -> Void)? = nil,
        onClick: ((AdCTAAction) -> Void)? = nil,
        onAvailabilityChanged: ((Bool) -> Void)? = nil,
        impressionSessionID: String? = nil
    ) {
        self.format = format
        self.externalAdId = externalAdId
        self.explicitClient = nil
        self.onImpression = onImpression
        self.onClick = onClick
        self.onAvailabilityChanged = onAvailabilityChanged
        self.impressionSessionID = impressionSessionID
    }

    /// Creates an ad view with an explicit client.
    public init(
        format: AdFormat,
        client: BetterAdsClient,
        externalAdId: String? = nil,
        onImpression: ((AdModel) -> Void)? = nil,
        onClick: ((AdCTAAction) -> Void)? = nil,
        onAvailabilityChanged: ((Bool) -> Void)? = nil,
        impressionSessionID: String? = nil
    ) {
        self.format = format
        self.externalAdId = externalAdId
        self.explicitClient = client
        self.onImpression = onImpression
        self.onClick = onClick
        self.onAvailabilityChanged = onAvailabilityChanged
        self.impressionSessionID = impressionSessionID
    }

    /// Backward-compatible alias — `onAction` is observation-only; the SDK still opens the CTA.
    public init(
        format: AdFormat,
        client: BetterAdsClient,
        externalAdId: String? = nil,
        onImpression: ((AdModel) -> Void)? = nil,
        onAction: ((AdCTAAction) -> Void)?,
        onAvailabilityChanged: ((Bool) -> Void)? = nil,
        impressionSessionID: String? = nil
    ) {
        self.init(
            format: format,
            client: client,
            externalAdId: externalAdId,
            onImpression: onImpression,
            onClick: onAction,
            onAvailabilityChanged: onAvailabilityChanged,
            impressionSessionID: impressionSessionID
        )
    }

    public var body: some View {
        Group {
            if let client = explicitClient ?? environmentClient {
                BetterAdContent(
                    client: client,
                    format: format,
                    externalAdId: externalAdId,
                    onImpression: onImpression,
                    onClick: onClick,
                    onAvailabilityChanged: onAvailabilityChanged,
                    impressionSessionID: impressionSessionID
                )
                .id("\(format.rawValue)|\(externalAdId ?? "")")
            } else {
                Color.clear
                    .frame(height: 0)
                    .accessibilityHidden(true)
                    .onAppear {
                        assertionFailure(
                            "BetterAdView requires a BetterAdsClient. Pass client: or use .betterAdsClient(_:)."
                        )
                    }
            }
        }
    }
}

// MARK: - Content

private struct BetterAdContent: View {
    let format: AdFormat
    let onImpression: ((AdModel) -> Void)?
    let onClick: ((AdCTAAction) -> Void)?
    let onAvailabilityChanged: ((Bool) -> Void)?
    let impressionSessionID: String?

    @StateObject private var viewModel: AdViewModel

    init(
        client: BetterAdsClient,
        format: AdFormat,
        externalAdId: String?,
        onImpression: ((AdModel) -> Void)?,
        onClick: ((AdCTAAction) -> Void)?,
        onAvailabilityChanged: ((Bool) -> Void)?,
        impressionSessionID: String?
    ) {
        self.format = format
        self.onImpression = onImpression
        self.onClick = onClick
        self.onAvailabilityChanged = onAvailabilityChanged
        self.impressionSessionID = impressionSessionID
        _viewModel = StateObject(
            wrappedValue: AdViewModel(
                client: client,
                type: AdType(format: format),
                externalAdId: externalAdId
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                AdSkeletonView(format: format)
            case .failed:
                EmptyView()
            case let .loaded(ad):
                layout(for: ad)
                    .onAdVisible(trackingKey: "\(impressionSessionID ?? "")|\(ad.adId)") {
                        if viewModel.trackImpressionIfNeeded(sessionID: impressionSessionID) {
                            onImpression?(ad)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            switch viewModel.state {
            case .loaded:
                onAvailabilityChanged?(true)
            case .failed:
                onAvailabilityChanged?(false)
            case .idle, .loading:
                break
            }
        }
        .onChange(of: viewModel.state) { _, state in
            switch state {
            case .loaded:
                onAvailabilityChanged?(true)
            case .failed:
                onAvailabilityChanged?(false)
            case .idle:
                Task { await viewModel.revalidate() }
            case .loading:
                break
            }
        }
        // First display only. Lazy lists cancel `.task` when the row leaves the
        // window — `loadIfNeeded` must not refetch a creative that is already cached.
        .task(id: viewModel.placementIdentity) {
            await viewModel.loadIfNeeded()
        }
        .onChange(of: impressionSessionID) { _, _ in
            viewModel.resetImpressionEligibility()
            Task { await viewModel.revalidate() }
        }
    }

    @ViewBuilder
    private func layout(for ad: AdModel) -> some View {
        switch format {
        case .compact, .banner, .card:
            HeroAdLayout(ad: ad, format: format, onCTA: handleCTA)
        case .interstitial:
            EmptyView()
        }
    }

    private func handleCTA() {
        guard let action = viewModel.handleClick() else { return }
        AdActionHandler.open(action)
        onClick?(action)
    }
}

#Preview("Compact") {
    HeroAdLayout(ad: .previewFixture(size: .compact), format: .compact, onCTA: {})
        .padding()
}

#Preview("Banner") {
    HeroAdLayout(ad: .previewFixture(size: .banner), format: .banner, onCTA: {})
        .padding()
}

#Preview("Card") {
    HeroAdLayout(ad: .previewFixture(size: .card), format: .card, onCTA: {})
        .padding()
}

#Preview("Banner skeleton") {
    AdSkeletonView(format: .banner)
        .padding()
}
