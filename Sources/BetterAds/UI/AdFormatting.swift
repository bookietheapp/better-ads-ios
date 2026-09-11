import SwiftUI

enum AdLayoutMetrics {
    static let advertisementLabelInset: CGFloat = 8
    static let advertisementLabelCornerRadius: CGFloat = 4
    static let advertisementLabelBackgroundOpacity: CGFloat = 0.72
    static let cornerRadius: CGFloat = 12
    static let skeletonFillOpacity: CGFloat = 0.10
    static let skeletonPulseOpacity: CGFloat = 0.55
    static let skeletonPulseDuration: TimeInterval = 0.9

    /// NativeOS Template 1x frames (logical px), authored against a 390 pt screen.
    ///
    /// These are reference sizes, not fixed frames — the rendered slot stretches to the
    /// host's content width at ``templateAspectRatio(for:)`` so it lines up with the
    /// surrounding layout on every device.
    static func templateSize(for format: AdFormat) -> CGSize {
        switch format {
        case .compact: return CGSize(width: 329, height: 51)
        case .banner: return CGSize(width: 345, height: 164)
        case .card: return CGSize(width: 336, height: 443)
        case .interstitial: return .zero
        }
    }

    /// Width-over-height ratio of the Template frame. Drives the rendered slot so a
    /// wider phone gets a wider ad instead of a centered 390 pt-era box.
    static func templateAspectRatio(for format: AdFormat) -> CGFloat {
        let size = templateSize(for: format)
        guard size.height > 0 else { return 1 }
        return size.width / size.height
    }

    /// Template-sized skeleton while Serve is in flight so the slot stays visible
    /// and lazy host lists (e.g. SwiftUI `LazyVStack`) still mount `.task` / `revalidate()`.
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
