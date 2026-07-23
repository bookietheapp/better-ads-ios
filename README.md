# Better Ads (iOS)

Standalone Swift package (`BetterAds`) that iOS apps use to **fetch ad creatives** and **report ad analytics** against a dedicated ads backend.

The host app renders ads; this SDK owns all networking for:

| Operation | Endpoint |
|-----------|----------|
| Fetch ad | `GET /ads/:type` |
| Impression | `POST /ads/:type/impressions` |
| Click | `POST /ads/:type/clicks` |

Rendering is out of scope — the SDK returns `AdModel` data only.

## Requirements

- iOS 17+ (aligned with the Bookie iOS app deployment target)
- Swift 5.9+
- No third-party dependencies

## Installation (Swift Package Manager)

### Xcode

1. **File → Add Package Dependencies…**
2. Enter the repository URL for this package
3. Add the `BetterAds` product to your app target

### `Package.swift`

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_ORG/better-ads-ios.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "BetterAds", package: "better-ads-ios"),
        ]
    ),
]
```

> Replace the URL / version once the package is published.

## Usage

```swift
import BetterAds

let client = BetterAdsClient(
    configuration: BetterAdsConfiguration(
        baseURL: URL(string: "https://ads.example.com")!,
        apiKey: "YOUR_API_KEY",          // optional — see Auth assumption below
        sessionID: sessionIdentifier,    // injected by host
        userID: currentUserID,           // optional
        locale: .current
    )
)

// Fetch (host renders)
let ad = try await client.fetchAd(type: AdType("home_banner"))

// When the ad appears on screen
client.trackImpression(for: ad.type)

// When the CTA is tapped
client.trackClick(for: ad.type, ctaValue: ad.cta.action.value)
```

Impression / click tracking is **best-effort and non-blocking**. Failures are logged and never thrown to the host, so analytics outages cannot break ad rendering.

## Public API

| API | Behavior |
|-----|----------|
| `BetterAdsClient(configuration:)` | Configure base URL + identity/locale |
| `fetchAd(type:) async throws -> AdModel` | Fetch & decode ad content |
| `trackImpression(for:)` | Fire-and-forget `POST …/impressions` |
| `trackClick(for:ctaValue:)` | Fire-and-forget `POST …/clicks` |

## Ad model

```text
AdModel
├── type
├── brand
├── images.hero / images.icon  →  1x / 2x / 3x signed URLs
├── headline
├── description
└── cta
    ├── title
    └── action.type  (url | deeplink)
        action.value
```

## Development

```bash
swift build
swift test
```

## Assumptions / open questions

See the handoff notes in the initial commit / engineering docs. In short:

1. **Auth** — optional `X-API-Key` header for now; backend team should confirm the real scheme.
2. **Identity** — `session_id`, `user_id`, and `locale` are injected by the host and forwarded on analytics POSTs.
3. **Hosting / CI** — GitHub Actions workflow is included as a starting point.
4. **License** — proprietary placeholder; confirm internal standard text.
5. **Offline queuing** — not implemented; failed analytics calls are logged only.
6. **Versioning** — recommend SemVer starting at `0.1.0` once published.
