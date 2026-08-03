import Foundation

/// Loads ad content and owns impression / click reporting for a single placement.
///
/// Creative selection is owned by the serve API: the view model revalidates on
/// appear / host surface refresh, keeps the current creative while fetching, and
/// only swaps UI when the payload changes.
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
    private var isRevalidating = false

    init(client: BetterAdsClient, type: AdType) {
        self.client = client
        self.type = type
        // Paint cached creative immediately so remounts don't flash a blank loading slot.
        if let cached = client.cachedAd(for: type) {
            self.state = .loaded(cached)
        }
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

    /// Asks the serve API whether this slot should keep or replace its creative.
    ///
    /// - Keeps the current creative visible while fetching (no flash).
    /// - Updates state only when the API returns a different payload.
    /// - Resets impression eligibility when `campaignId` changes.
    func revalidate() async {
        guard !isRevalidating else { return }
        isRevalidating = true
        defer { isRevalidating = false }

        let previous = ad
        let hadContent = previous != nil
        // Only show the blank loading placeholder when we have nothing to display yet.
        if !hadContent {
            state = .loading
        }

        do {
            let fresh = try await client.fetchAd(type: type)
            applyServeResult(previous: previous, fresh: fresh)
        } catch is CancellationError {
            // Lazy stacks often cancel the first task (0-height placeholder). Do not
            // permanently fail — leave idle so a later appear can fetch.
            if !hadContent { state = .idle }
        } catch {
            if !hadContent {
                state = .failed((error as? BetterAdsError)?.localizedDescription ?? error.localizedDescription)
            }
        }
    }

    /// Backward-compatible alias used by older call sites / tests.
    func loadIfNeeded() async {
        await revalidate()
    }

    /// Called when the rendered ad content appears. Fires at most once per campaign
    /// for this view model instance.
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

    private func applyServeResult(previous: AdModel?, fresh: AdModel) {
        guard previous != fresh else { return }
        if previous?.campaignId != fresh.campaignId {
            didTrackImpression = false
        }
        state = .loaded(fresh)
    }
}
