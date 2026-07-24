import SwiftUI

private enum BetterAdsClientKey: EnvironmentKey {
    static let defaultValue: BetterAdsClient? = nil
}

extension EnvironmentValues {
    /// Shared Better Ads client for `BetterAdView` instances that omit an explicit client.
    public var betterAdsClient: BetterAdsClient? {
        get { self[BetterAdsClientKey.self] }
        set { self[BetterAdsClientKey.self] = newValue }
    }
}

extension View {
    /// Injects a `BetterAdsClient` into the environment for descendant `BetterAdView`s.
    public func betterAdsClient(_ client: BetterAdsClient) -> some View {
        environment(\.betterAdsClient, client)
    }
}
