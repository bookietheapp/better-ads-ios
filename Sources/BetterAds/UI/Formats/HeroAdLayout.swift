import SwiftUI

/// NativeOS image-only Design: hero fills the Template 1x frame; the image is the tap target.
struct HeroAdLayout: View {
    let ad: AdModel
    let format: AdFormat
    let onCTA: () -> Void

    private var frameSize: CGSize {
        AdLayoutMetrics.templateSize(for: format)
    }

    var body: some View {
        Button(action: onCTA) {
            ZStack(alignment: .topTrailing) {
                AdRemoteImage(
                    url: ad.images.hero.url(for: AdDisplayScale.current),
                    pointSize: frameSize,
                    placeholder: {
                        Color.clear
                            .frame(width: frameSize.width, height: frameSize.height)
                    },
                    imageContent: { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: frameSize.width, height: frameSize.height)
                            .clipped()
                    }
                )
                .frame(width: frameSize.width, height: frameSize.height)

                AdAdvertisementLabel(style: AdLayoutMetrics.advertisementLabelStyle(for: format))
            }
        }
        .buttonStyle(.plain)
        .frame(width: frameSize.width, height: frameSize.height)
        .clipShape(RoundedRectangle(cornerRadius: AdLayoutMetrics.cornerRadius, style: .continuous))
        .frame(maxWidth: .infinity)
        .accessibilityLabel(String(localized: "Advertisement", bundle: .module))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Compact") {
    HeroAdLayout(ad: .previewFixture(size: .compact), format: .compact, onCTA: {})
        .padding()
}

#Preview("Banner") {
    HeroAdLayout(ad: .previewFixture(size: .banner), format: .banner, onCTA: {})
        .padding()
}

#Preview("Card") {
    HeroAdLayout(ad: .previewFixture(size: .card), format: .card, onCTA: {})
        .padding()
}
