// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BetterAds",
    platforms: [
        // Matches Bookie iOS app deployment target (IPHONEOS_DEPLOYMENT_TARGET = 17.0).
        .iOS(.v17),
        .macOS(.v14), // Enables `swift test` on CI / developer machines.
    ],
    products: [
        .library(
            name: "BetterAds",
            targets: ["BetterAds"]
        ),
    ],
    targets: [
        .target(
            name: "BetterAds"
        ),
        .testTarget(
            name: "BetterAdsTests",
            dependencies: ["BetterAds"]
        ),
    ]
)
