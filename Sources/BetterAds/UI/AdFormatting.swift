import SwiftUI

enum AdLayoutMetrics {
    static let advertisementLabelInset: CGFloat = 8
    static let advertisementLabelCornerRadius: CGFloat = 4
    static let advertisementLabelBackgroundOpacity: CGFloat = 0.72
    static let cornerRadius: CGFloat = 12

    /// NativeOS Template 1x frames (logical px).
    static func templateSize(for format: AdFormat) -> CGSize {
        switch format {
        case .compact: return CGSize(width: 329, height: 51)
        case .banner: return CGSize(width: 345, height: 164)
        case .card: return CGSize(width: 336, height: 443)
        case .interstitial: return .zero
        }
    }

    /// Non-zero height while serve is in flight so lazy host lists (e.g. SwiftUI `LazyVStack`)
    /// still mount the slot and run `.task` / `revalidate()`.
    static func loadingPlaceholderHeight(for format: AdFormat) -> CGFloat {
        templateSize(for: format).height
    }

    static func advertisementLabelStyle(for format: AdFormat) -> AdAdvertisementLabelStyle {
        format == .card ? .full : .short
    }
}

/// Fallback typography for the advertisement disclosure chip.
enum AdTypography {
    static func caption(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
}
