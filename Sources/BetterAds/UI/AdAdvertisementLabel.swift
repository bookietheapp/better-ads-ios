import SwiftUI

enum AdAdvertisementLabelStyle {
    /// Compact / banner — short “Ad”.
    case short
    /// Card — full “Advertisement”.
    case full
}

/// Meta/Google-style frosted “Ad” / “Advertisement” chip (Bookie `PlacementAdAdvertisementLabel`).
struct AdAdvertisementLabel: View {
    var style: AdAdvertisementLabelStyle = .short

    private var title: String {
        switch style {
        case .short:
            return String(localized: "Ad", bundle: .module)
        case .full:
            return String(localized: "Advertisement", bundle: .module)
        }
    }

    var body: some View {
        Text(title)
            .font(AdTypography.caption(size: 10))
            .foregroundStyle(Color.black.opacity(0.8))
            .padding(.horizontal, style == .short ? 6 : 8)
            .padding(.vertical, 3)
            .background(
                Color.white.opacity(AdLayoutMetrics.advertisementLabelBackgroundOpacity)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: AdLayoutMetrics.advertisementLabelCornerRadius,
                    style: .continuous
                )
            )
            .padding(.top, AdLayoutMetrics.advertisementLabelInset)
            .padding(.trailing, AdLayoutMetrics.advertisementLabelInset)
            .accessibilityLabel(String(localized: "Advertisement", bundle: .module))
            .accessibilityAddTraits(.isStaticText)
    }
}
