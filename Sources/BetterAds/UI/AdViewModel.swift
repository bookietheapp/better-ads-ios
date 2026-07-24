import Foundation

/// Loads ad content and owns impression / click reporting for a single placement.
@MainActor
final class AdViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(AdModel)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let client: BetterAdsClient
    private let type: AdType
    private var didTrackImpression = false

    init(client: BetterAdsClient, type: AdType) {
        self.client = client
        self.type = type
    }

    /// Test / preview seam for a preloaded model (skips network).
    init(client: BetterAdsClient, type: AdType, preloadedAd: AdModel) {
        self.client = client
        self.type = type
        self.state = .loaded(preloadedAd)
    }

    var ad: AdModel? {
        if case let .loaded(ad) = state { return ad }
        return nil
    }

    func loadIfNeeded() async {
        switch state {
        case .loading, .loaded:
            return
        case .idle, .failed:
            break
        }

        state = .loading
        do {
            let ad = try await client.fetchAd(type: type)
            state = .loaded(ad)
        } catch {
            state = .failed((error as? BetterAdsError)?.localizedDescription ?? error.localizedDescription)
        }
    }

    /// Called when the rendered ad content appears. Fires at most once per view model.
    /// - Returns: `true` when an impression was newly tracked.
    @discardableResult
    func trackImpressionIfNeeded() -> Bool {
        guard case .loaded = state, !didTrackImpression else { return false }
        didTrackImpression = true
        client.trackImpression(for: type)
        return true
    }

    /// Tracks the click and returns the CTA action for host / system navigation.
    @discardableResult
    func handleClick() -> AdCTAAction? {
        guard let ad else { return nil }
        client.trackClick(for: type, ctaValue: ad.cta.action.value)
        return ad.cta.action
    }
}
