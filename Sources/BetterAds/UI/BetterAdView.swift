import SwiftUI

/// Ready-to-display ad view for a Bookie-parity format (`compact` / `banner` / `card`).
///
/// Lifecycle (all owned by the SDK — hosts only place this view):
/// - Revalidates with the serve API when the view appears.
/// - Keeps the current creative on screen while fetching (no flash).
/// - The API decides whether to return the same or a new creative; UI swaps only
///   when the payload changes.
/// - Not tied to every SwiftUI body recomposition.
///
/// The SDK fetches, renders, tracks impression/click, and opens CTA destinations.
/// Host callbacks are observation-only (e.g. Firebase bridge) — they do not own navigation.
public struct BetterAdView: View {
    private let format: AdFormat
    private let explicitClient: BetterAdsClient?
    private let onClick: ((AdCTAAction) -> Void)?
    private let onImpression: ((AdModel) -> Void)?
    private let onAvailabilityChanged: ((Bool) -> Void)?

    @Environment(\.betterAdsClient) private var environmentClient

    /// Creates an ad view that reads `BetterAdsClient` from the environment.
    ///
    /// - Parameters:
    ///   - onImpression: Optional host observation after the SDK records an impression.
    ///   - onClick: Optional host observation after the SDK records a click and opens the CTA.
    public init(
        format: AdFormat,
        onImpression: ((AdModel) -> Void)? = nil,
        onClick: ((AdCTAAction) -> Void)? = nil,
        onAvailabilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.format = format
        self.explicitClient = nil
        self.onImpression = onImpression
        self.onClick = onClick
        self.onAvailabilityChanged = onAvailabilityChanged
    }

    /// Creates an ad view with an explicit client.
    public init(
        format: AdFormat,
        client: BetterAdsClient,
        onImpression: ((AdModel) -> Void)? = nil,
        onClick: ((AdCTAAction) -> Void)? = nil,
        onAvailabilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.format = format
        self.explicitClient = client
        self.onImpression = onImpression
        self.onClick = onClick
        self.onAvailabilityChanged = onAvailabilityChanged
    }

    /// Backward-compatible alias — `onAction` is observation-only; the SDK still opens the CTA.
    public init(
        format: AdFormat,
        client: BetterAdsClient,
        onImpression: ((AdModel) -> Void)? = nil,
        onAction: ((AdCTAAction) -> Void)?,
        onAvailabilityChanged: ((Bool) -> Void)? = nil
    ) {
        self.init(
            format: format,
            client: client,
            onImpression: onImpression,
            onClick: onAction,
            onAvailabilityChanged: onAvailabilityChanged
        )
    }

    public var body: some View {
        Group {
            if let client = explicitClient ?? environmentClient {
                BetterAdContent(
                    client: client,
                    format: format,
                    onImpression: onImpression,
                    onClick: onClick,
                    onAvailabilityChanged: onAvailabilityChanged
                )
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

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: AdViewModel

    init(
        client: BetterAdsClient,
        format: AdFormat,
        onImpression: ((AdModel) -> Void)?,
        onClick: ((AdCTAAction) -> Void)?,
        onAvailabilityChanged: ((Bool) -> Void)?
    ) {
        self.format = format
        self.onImpression = onImpression
        self.onClick = onClick
        self.onAvailabilityChanged = onAvailabilityChanged
        _viewModel = StateObject(
            wrappedValue: AdViewModel(client: client, type: AdType(format: format))
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: AdLayoutMetrics.loadingPlaceholderHeight(for: format))
                    .accessibilityHidden(true)
            case .failed:
                EmptyView()
            case let .loaded(ad):
                layout(for: ad)
                    .onAppear {
                        if viewModel.trackImpressionIfNeeded() {
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
        // SDK-owned: revalidate on appear / foreground — not host refresh tokens.
        .task(id: format) {
            await viewModel.revalidate()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.revalidate() }
        }
    }

    @ViewBuilder
    private func layout(for ad: AdModel) -> some View {
        switch format {
        case .compact:
            CompactAdLayout(ad: ad, onCTA: handleCTA)
        case .banner:
            BannerAdLayout(ad: ad, onCTA: handleCTA)
        case .card:
            CardAdLayout(ad: ad, onCTA: handleCTA)
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
    CompactAdLayout(ad: .previewFixture(size: .compact), onCTA: {})
        .padding()
}

#Preview("Banner") {
    BannerAdLayout(ad: .previewFixture(size: .banner), onCTA: {})
        .padding()
}

#Preview("Card") {
    CardAdLayout(ad: .previewFixture(size: .card), onCTA: {})
        .padding()
}
