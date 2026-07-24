import SwiftUI

/// Ready-to-display ad view for a Bookie-parity format (`compact` / `banner` / `card`).
///
/// Fetches, renders the matching layout, and tracks impression / click. Host apps
/// may optionally observe those moments (e.g. Firebase bridge during migration).
public struct BetterAdView: View {
    private let format: AdFormat
    private let explicitClient: BetterAdsClient?
    private let onAction: ((AdCTAAction) -> Void)?
    private let onImpression: ((AdModel) -> Void)?

    @Environment(\.betterAdsClient) private var environmentClient

    /// Creates an ad view that reads `BetterAdsClient` from the environment.
    public init(
        format: AdFormat,
        onImpression: ((AdModel) -> Void)? = nil,
        onAction: ((AdCTAAction) -> Void)? = nil
    ) {
        self.format = format
        self.explicitClient = nil
        self.onImpression = onImpression
        self.onAction = onAction
    }

    /// Creates an ad view with an explicit client.
    public init(
        format: AdFormat,
        client: BetterAdsClient,
        onImpression: ((AdModel) -> Void)? = nil,
        onAction: ((AdCTAAction) -> Void)? = nil
    ) {
        self.format = format
        self.explicitClient = client
        self.onImpression = onImpression
        self.onAction = onAction
    }

    public var body: some View {
        Group {
            if let client = explicitClient ?? environmentClient {
                BetterAdContent(
                    client: client,
                    format: format,
                    onImpression: onImpression,
                    onAction: onAction
                )
                .id(format.rawValue)
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
    let onAction: ((AdCTAAction) -> Void)?

    @StateObject private var viewModel: AdViewModel
    @Environment(\.openURL) private var openURL

    init(
        client: BetterAdsClient,
        format: AdFormat,
        onImpression: ((AdModel) -> Void)?,
        onAction: ((AdCTAAction) -> Void)?
    ) {
        self.format = format
        self.onImpression = onImpression
        self.onAction = onAction
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
                    .frame(height: format == .banner ? AdLayoutMetrics.bannerHeight : 0)
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
        .task {
            await viewModel.loadIfNeeded()
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

        if let onAction {
            onAction(action)
            return
        }

        switch action.type {
        case .url:
            if let url = URL(string: action.value) {
                openURL(url)
            }
        case .deeplink:
            break
        }
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
