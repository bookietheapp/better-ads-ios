import SwiftUI

/// NativeOS image-only Design: hero fills the host's content width at the Template
/// aspect ratio; the image is the tap target.
struct HeroAdLayout: View {
    let ad: AdModel
    let format: AdFormat
    let onCTA: () -> Void

    private var aspectRatio: CGFloat {
        AdLayoutMetrics.templateAspectRatio(for: format)
    }

    var body: some View {
        Button(action: onCTA) {
            Color.clear
                .overlay {
                    AdRemoteImage(
                        url: ad.images.hero.url(for: AdDisplayScale.current),
                        placeholder: { AdSkeletonFill() },
                        imageContent: { image in
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    )
                }
                .clipped()
                .overlay(alignment: .topTrailing) {
                    AdAdvertisementLabel(style: AdLayoutMetrics.advertisementLabelStyle(for: format))
                }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AdLayoutMetrics.cornerRadius, style: .continuous))
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
