# Better Ads (iOS)

Swift package (`BetterAds`) for host apps (starting with Bookie). The SDK returns **ready-to-display SwiftUI ad views** and owns:

1. Creative load (fixture or remote)
2. Impression / click reporting to the ads backend (when remote)
3. Opening the CTA (Safari / deeplink)

Host apps only configure a client, place `BetterAdView`, and optionally observe events (e.g. Firebase).

**Platforms:** iOS 17+ (macOS 14 for `swift test` only).

## Install (SPM)

### Local (spike)

In Xcode → Package Dependencies → Add Local → select this folder, or in `Package.swift` / Xcode project:

```text
../../better-ads/better-ads-ios
```

Product: `BetterAds`.

### Git

```text
git@github.com:eduardobookie/better-ads-ios.git
```

## Content modes

| `BetterAdsContentMode` | Behavior |
|------------------------|----------|
| `.fixture` (**spike default**) | Built-in sample creatives. No network, no `baseURL`, no auth. Ads analytics POSTs are skipped. |
| `.serveV1` (**current remote**) | SDK-owned serve endpoint (`size` + optional `app=` via `appName` while unauthenticated) |
| `.bookieGetAd` | Legacy: `GET /getAd?size={format}` (+ optional Bearer via `BetterAdsAuthProviding`) — host `baseURL` |
| `.dedicatedAPI` | Future: `GET /ads/{format}` — host `baseURL` |

Hosts never configure the serve URL for `.serveV1`. Remote calls send `X-Api-Key: {apiKey}` (App API key from NativeOS Portal, `nos_…`). Keep `appName` aligned with the Portal App name until the backend is key-only.

Ad events are batched to `POST /api/v1/events` (1–500 per request). The SDK flushes on enqueue, every ~30s, and on app background. See [`docs/IDENTITY_AND_ANALYTICS.md`](../docs/IDENTITY_AND_ANALYTICS.md) and [`docs/BOOKIE_INTEGRATION.md`](../docs/BOOKIE_INTEGRATION.md).

## Formats

| `AdFormat` | Layout |
|------------|--------|
| `.compact` | Row: 50×53 hero, wordmark/headline, description, capsule CTA; “Ad” chip |
| `.banner` | Fixed height 164; left copy + 205×164 hero; “Ad” chip |
| `.card` | Vertical card with “Advertisement” chip |
| `.interstitial` | No UI (skipped) |

Payload shape matches Bookie `PlacementAdResponse` (`campaignId`, hex colors, CTA colors, hero/icon `1x`/`2x`/`3x`, `*emphasis*` in description).

## Usage

### Spike / fixture (recommended today)

```swift
import BetterAds
import SwiftUI

enum AppAds {
    static let client = BetterAdsClient.fixture(apiKey: "YOUR_BETTER_ADS_KEY")
}

struct HomeView: View {
    var body: some View {
        ScrollView {
            // Explicit client (Bookie host pattern)
            BetterAdView(
                format: .banner,
                client: AppAds.client,
                onImpression: { ad in
                    // Optional host observation (e.g. Firebase) — do not open the CTA here
                    _ = ad.campaignId
                },
                onClick: { action in
                    // Optional host observation after the SDK opens the CTA
                    _ = action.value
                }
            )

            BetterAdView(format: .compact, client: AppAds.client)
            BetterAdView(format: .card, client: AppAds.client)
        }
    }
}
```

### Environment client (alternative)

Inject once higher in the tree instead of passing `client:` on every view:

```swift
ScrollView {
    BetterAdView(format: .banner)
    BetterAdView(format: .compact)
}
.betterAdsClient(AppAds.client)
```

`BetterAdView` requires a client via `client:` **or** `.betterAdsClient(_:)`. Missing both asserts in debug and renders empty.

### Remote (`serveV1` — production)

```swift
let client = BetterAdsClient(
    configuration: BetterAdsConfiguration(
        apiKey: BookieSecrets.nativeOSAppAPIKey, // nos_… from NativeOS Portal
        contentMode: .serveV1,
        appName: "Bookie", // must match Portal App; remove once key-only auth ships
        userID: userId,    // optional; or call client.setUserID later
        locale: .current
    )
)

// On login / logout — only host identity concern:
client.setUserID(loggedInUserId) // or nil when logged out / guest
```

The SDK owns `device_id` (persisted) and `session_id` (rotates on logout when you clear user id). See [`docs/IDENTITY_AND_ANALYTICS.md`](../docs/IDENTITY_AND_ANALYTICS.md).

## What the SDK owns vs the host

| Concern | Owner |
|---------|--------|
| Persist `device_id` / manage `session_id` | SDK |
| Set `user_id` on auth (`setUserID`) | Host |
| Fetch creative | SDK |
| Render layout | SDK (`BetterAdView`) |
| Ads-backend impression / click events | SDK → batched `POST /api/v1/events` (no-op in `.fixture`) |
| Open CTA (`.url` → `SFSafariViewController`, `.deeplink` → `UIApplication.open`) | SDK |
| Host analytics (Firebase `impression` / `placement_ad_click`, etc.) | Host via `onImpression` / `onClick` only |

Do **not** open ad URLs in host callbacks — observation only.

## Development

```bash
swift build
swift test
```

In Xcode, open `Package.swift` and use `#Preview` on the layout files under `Sources/BetterAds/UI/Formats/` (neutral “Sample Brand” fixture).
