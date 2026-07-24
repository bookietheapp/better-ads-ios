# Better Ads (iOS)

Standalone Swift package (`BetterAds`) that returns **ready-to-display SwiftUI ad views** matching Bookie’s in-app placement ads, and reports impressions / clicks to a dedicated ads backend.

## Formats (Bookie parity)

Aligned with Bookie `PlacementAdSize` + layouts:

| Format | Bookie view | Layout |
|--------|-------------|--------|
| `.compact` | `PlacementAdCompactView` | Row: 50×53 hero, wordmark/headline, description, capsule CTA; “Ad” chip |
| `.banner` | `PlacementAdBannerView` | Fixed height 164; left copy (50% width) + 205×164 hero; “Ad” chip |
| `.card` | `PlacementAdCardView` | Vertical: wordmark → 205×164 hero → centered title block → full-width CTA; “Advertisement” chip |
| `.interstitial` | _(skipped)_ | No UI (same as Bookie) |

Creative payload mirrors Bookie `PlacementAdResponse` (`campaignId`, hex colors, CTA colors, hero/icon 1x/2x/3x, `*emphasis*` in description).

## Usage

```swift
import BetterAds
import SwiftUI

struct HomeView: View {
    private let ads = BetterAdsClient(
        configuration: BetterAdsConfiguration(
            baseURL: URL(string: "https://ads.example.com")!,
            apiKey: "YOUR_API_KEY",
            sessionID: sessionIdentifier,
            userID: currentUserID,
            locale: .current
        )
    )

    var body: some View {
        ScrollView {
            BetterAdView(format: .banner) { action in
                // Optional — required for deeplinks.
                // If omitted, `.url` opens via SwiftUI `openURL`.
                handle(action)
            }

            BetterAdView(format: .compact)
            BetterAdView(format: .card)
        }
        .betterAdsClient(ads)
    }
}
```

### Tracking (owned by the view)

| Event | When |
|-------|------|
| Impression | Loaded creative appears (`onAppear`) — once per view model |
| Click | CTA tapped → analytics POST, then `onAction` / `openURL` |

Host apps should **not** fire ad analytics themselves.

## Visual review

Open `Package.swift` in Xcode and use `#Preview` on:

- `CompactAdLayout`
- `BannerAdLayout`
- `CardAdLayout`

Fixtures use a neutral sample brand (no real advertiser).

## Development

```bash
swift build
swift test
```

## Notes / gaps vs Bookie app

1. **Fonts** — Bookie uses Canela + app design-system faces. The SDK uses system serif at the same sizes / tracking / line heights so **geometry matches**; swap in Bookie font providers later if pixel-perfect type is required.
2. **Images** — SDK uses `AsyncImage`; Bookie uses `RemoteImage` with pixel-size hints. Visual result is equivalent for layout.
3. **Auth / analytics backend** — dedicated ads service (`/ads/:type`, `/impressions`, `/clicks`); not Bookie’s Firebase `impression` / `placement_ad_click`.
4. **Copy** — “Ad” / “Advertisement” localized in the package (`en` / `de` / `pt-BR`), matching Bookie intent.
