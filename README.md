# Better Ads (iOS)

Swift package (`BetterAds`) for host apps (starting with Bookie). The SDK returns **ready-to-display SwiftUI ad views** and owns:

1. Creative load (fixture or remote)
2. Impression / click reporting to the ads backend (when remote)
3. Opening the CTA (Safari / deeplink)

Host apps only configure a client, place `BetterAdView`, and optionally observe events (e.g. Firebase).

**Platforms:** iOS 17+ (macOS 14 for `swift test` only).

## Install (SPM)

### Git (recommended for host apps)

Repository: [github.com/bookietheapp/better-ads-ios](https://github.com/bookietheapp/better-ads-ios)

In Xcode → **Package Dependencies** → **Add Package** → paste:

```text
https://github.com/bookietheapp/better-ads-ios.git
```

Product: `BetterAds`. Pin to a **version tag** (e.g. `0.3.1`) or `main` while iterating.

### Local (SDK development)

In Xcode → Package Dependencies → Add Local → select this folder, or in `Package.swift` / Xcode project:

```text
../../better-ads/better-ads-ios
```

## Content modes

| `BetterAdsContentMode` | Behavior |
|------------------------|----------|
| `.fixture` (**spike default**) | Built-in sample creatives. No network, no `baseURL`, no auth. Ads analytics POSTs are skipped. |
| `.serveV1` (**current remote**) | SDK-owned serve endpoint (`size` + optional `app=` via `appName`, optional `externalAdId` for keyed Serve) |
| `.bookieGetAd` | Legacy: `GET /getAd?size={format}` (+ optional Bearer via `BetterAdsAuthProviding`) — host `baseURL` |
| `.dedicatedAPI` | Future: `GET /ads/{format}` — host `baseURL` |

Hosts never configure the serve URL for `.serveV1`. Remote calls send `X-Api-Key: {apiKey}` (App API key from NativeOS Portal, `nos_…`). Keep `appName` aligned with the Portal App name until the backend is key-only.

Ad events are batched to `POST /api/v1/events` (1–500 per request). The SDK flushes on enqueue, every ~30s, and on app background. See [`docs/IDENTITY_AND_ANALYTICS.md`](../docs/IDENTITY_AND_ANALYTICS.md) and [`docs/BOOKIE_INTEGRATION.md`](../docs/BOOKIE_INTEGRATION.md).

## Formats

| `AdFormat` | Template 1x frame (logical px) |
|------------|--------|
| `.compact` | 329 × 51 hero image; “Ad” chip |
| `.banner` | 345 × 164 hero image; “Ad” chip |
| `.card` | 336 × 443 hero image; “Advertisement” chip |
| `.interstitial` | No UI (Serve has no interstitial template) |

Serve returns a slim Design: `adId`, `campaignId`, `size`, `images.hero` (`1x` / `2x` / `3x`), and `ctaLink`. The SDK renders the hero as the entire ad and opens `ctaLink` on tap. Do not overlay headline, description, brand, or a CTA button.

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
                    _ = ad.adId
                },
                onClick: { action in
                    // Optional host observation after the SDK opens ctaLink
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

### Keyed Serve (`externalAdId`)

Unkeyed `BetterAdView(format:)` still picks from ads **without** an External Ad Id.

To fetch a specific Publisher-owned ad (for example Book of the Week), pass `externalAdId`. On keyed **404**, the SDK surfaces “no ad” and does **not** retry as unkeyed Serve. Impressions and clicks still use `adId` from the payload.

```swift
// Placement
BetterAdView(
    format: .banner,
    client: AppAds.client,
    externalAdId: "book_of_the_week_de"
)

// Programmatic
let ad = try await AppAds.client.fetchAd(
    format: .banner,
    externalAdId: "book_of_the_week_de"
)
```

## What the SDK owns vs the host

| Concern | Owner |
|---------|--------|
| Persist `device_id` / manage `session_id` | SDK |
| Set `user_id` on auth (`setUserID`) | Host |
| Fetch creative | SDK |
| Render layout | SDK (`BetterAdView`) |
| Ads-backend impression / click events | SDK → batched `POST /api/v1/events` (no-op in `.fixture`) |
| Open CTA (`ctaLink` → `SFSafariViewController` for http(s), otherwise `UIApplication.open`) | SDK |
| Host analytics (Firebase `impression` / `placement_ad_click`, etc.) | Host via `onImpression` / `onClick` only |

Do **not** open ad URLs in host callbacks — observation only.

## Development

```bash
swift build
swift test
```

In Xcode, open `Package.swift` and use `#Preview` on `HeroAdLayout` under `Sources/BetterAds/UI/Formats/`.
