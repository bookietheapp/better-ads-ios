import SwiftUI

/// Template-sized placeholder shown while Serve is in flight.
///
/// Matches the loaded hero frame (size, corner radius, Ad chip) so the slot does
/// not collapse or flash empty. Motion is a gentle pulse; it is disabled when
/// Reduce Motion is on.
struct AdSkeletonView: View {
    let format: AdFormat

    private var frameSize: CGSize {
        AdLayoutMetrics.templateSize(for: format)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AdSkeletonFill()
            AdAdvertisementLabel(style: AdLayoutMetrics.advertisementLabelStyle(for: format))
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .clipShape(RoundedRectangle(cornerRadius: AdLayoutMetrics.cornerRadius, style: .continuous))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Loading advertisement", bundle: .module))
    }
}

/// Pulsing fill used by ``AdSkeletonView`` and as the hero-image load placeholder.
struct AdSkeletonFill: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsed = false

    var body: some View {
        RoundedRectangle(cornerRadius: AdLayoutMetrics.cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(AdLayoutMetrics.skeletonFillOpacity))
            .opacity(reduceMotion ? 1 : (pulsed ? AdLayoutMetrics.skeletonPulseOpacity : 1))
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: AdLayoutMetrics.skeletonPulseDuration)
                    .repeatForever(autoreverses: true),
                value: pulsed
            )
            .onAppear { pulsed = true }
            .accessibilityHidden(true)
    }
}

#Preview("Banner skeleton") {
    AdSkeletonView(format: .banner)
        .padding()
}

#Preview("Compact skeleton") {
    AdSkeletonView(format: .compact)
        .padding()
}

#Preview("Card skeleton") {
    AdSkeletonView(format: .card)
        .padding()
}
