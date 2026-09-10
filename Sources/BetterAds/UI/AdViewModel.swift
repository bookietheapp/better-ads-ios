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
    private let externalAdId: String?
    private var didTrackImpression = false
    private var isRevalidating = false

    init(client: BetterAdsClient, type: AdType, externalAdId: String? = nil) {
        self.client = client
        self.type = type
        self.externalAdId = ExternalAdId.normalize(externalAdId)
        // Paint cached creative immediately so remounts don't flash a blank loading slot.
        if let cached = client.cachedAd(for: type, externalAdId: self.externalAdId) {
            self.state = .loaded(cached)
        }
    }

    /// Test / preview seam for a preloaded model (skips network).
    init(client: BetterAdsClient, type: AdType, preloadedAd: AdModel, externalAdId: String? = nil) {
        self.client = client
        self.type = type
        self.externalAdId = ExternalAdId.normalize(externalAdId)
        self.state = .loaded(preloadedAd)
    }

    var ad: AdModel? {
        if case let .loaded(ad) = state { return ad }
        return nil
    }

    var placementIdentity: String {
        AdResponseCache.key(type: type, externalAdId: externalAdId)
    }

    /// Asks the serve API whether this slot should keep or replace its creative.
    ///
    /// - Keeps the current creative visible while fetching (no flash).
    /// - Updates state only when the API returns a different payload.
    /// - Resets impression eligibility when `adId` changes.
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
            let fresh = try await client.fetchAd(type: type, externalAdId: externalAdId)
            applyServeResult(previous: previous, fresh: fresh)
        } catch is CancellationError {
            // Lazy stacks may cancel after fetch; creative is still in the client cache.
            if !hadContent {
                if let cached = client.cachedAd(for: type, externalAdId: externalAdId) {
                    state = .loaded(cached)
                } else {
                    state = .idle
                }
            }
        } catch {
            let message = (error as? BetterAdsError)?.localizedDescription ?? error.localizedDescription
            // Keyed 404 is a definitive miss — hide the slot. Do not keep a previous
            // creative and do not retry as unkeyed Serve.
            if externalAdId != nil, Self.isNoEligibleAd(error) {
                state = .failed(message)
            } else if !hadContent {
                state = .failed(message)
            }
        }
    }

    /// Backward-compatible alias used by older call sites / tests.
    func loadIfNeeded() async {
        await revalidate()
    }

    /// Called when the rendered ad content appears. Fires at most once per `adId`
    /// for this view model instance.
    /// - Returns: `true` when an impression was newly tracked.
    @discardableResult
    func trackImpressionIfNeeded() -> Bool {
        guard case .loaded = state, !didTrackImpression, let ad else { return false }
        didTrackImpression = true
        client.trackImpression(adId: ad.adId)
        return true
    }

    /// Tracks the click and returns the CTA action for host / system navigation.
    @discardableResult
    func handleClick() -> AdCTAAction? {
        guard let ad else { return nil }
        client.trackClick(adId: ad.adId, ctaValue: ad.ctaLink)
        return ad.ctaAction
    }

    private func applyServeResult(previous: AdModel?, fresh: AdModel) {
        guard previous != fresh else { return }
        if previous?.adId != fresh.adId {
            didTrackImpression = false
        }
        state = .loaded(fresh)
    }

    private static func isNoEligibleAd(_ error: Error) -> Bool {
        guard let error = error as? BetterAdsError else { return false }
        switch error {
        case .unknownAdType, .httpStatus(code: 404, body: _):
            return true
        default:
            return false
        }
    }
}
