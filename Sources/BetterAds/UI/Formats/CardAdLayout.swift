import SwiftUI

/// Bookie-parity card placement (`PlacementAdCardView`).
struct CardAdLayout: View {
    let ad: AdModel
    let onCTA: () -> Void

    /// Figma Title/Serif Title/Large: Canela Medium 22 / tracking -0.44.
    private static let descriptionFontSize: CGFloat = 22
    private static let descriptionLineHeight: CGFloat = 33
    private static let descriptionTracking: CGFloat = -0.44
    private static let descriptionBlockMinHeight: CGFloat = 99

    private var descriptionLineSpacing: CGFloat {
        max(0, Self.descriptionLineHeight - (Self.descriptionFontSize * 1.2))
    }

    private var backgroundColor: Color {
        AdFormatting.swiftUIColor(fromHex: ad.backgroundColor, fallback: Color.gray.opacity(0.2))
    }

    private var textColor: Color {
        AdFormatting.swiftUIColor(fromHex: ad.textColor, fallback: .black)
    }

    private var buttonBackground: Color {
        AdFormatting.swiftUIColor(fromHex: ad.cta.ctaButtonColor, fallback: .white)
    }

    private var buttonTitleColor: Color {
        AdFormatting.swiftUIColor(fromHex: ad.cta.ctaTitleColor, fallback: .black)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                headlineView
                    .padding(.top, 32)

                heroImage
                    .padding(8)

                VStack(spacing: 16) {
                    Text(
                        AdFormatting.attributedDescription(
                            ad.description,
                            baseColor: textColor,
                            baseFont: AdTypography.serif(Self.descriptionFontSize),
                            emphasisFont: AdTypography.serifItalic(Self.descriptionFontSize)
                        )
                    )
                    .tracking(Self.descriptionTracking)
                    .lineSpacing(descriptionLineSpacing)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Self.descriptionBlockMinHeight)
                    .fixedSize(horizontal: false, vertical: true)

                    Button(action: onCTA) {
                        Text(ad.cta.title)
                            .font(AdTypography.bodyHeavy(size: 16))
                            .foregroundStyle(buttonTitleColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(buttonBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)

            AdAdvertisementLabel(style: .full)
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AdLayoutMetrics.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var headlineView: some View {
        if let wordmarkURL = ad.images.icon.url(for: AdDisplayScale.current) {
            AdRemoteImage(
                url: wordmarkURL,
                pointSize: CGSize(width: 109, height: 17),
                placeholder: {
                    Text(ad.headline)
                        .font(AdTypography.serif(Self.descriptionFontSize))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                },
                imageContent: { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: 17)
                }
            )
            .frame(height: 17)
            .accessibilityLabel(ad.headline)
        } else {
            Text(ad.headline)
                .font(AdTypography.serif(Self.descriptionFontSize))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
    }

    private var heroImage: some View {
        AdRemoteImage(
            url: ad.images.hero.url(for: AdDisplayScale.current),
            pointSize: CGSize(width: 205, height: 164),
            placeholder: {
                Color.clear
                    .frame(width: 205, height: 164)
            },
            imageContent: { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 205, height: 164)
                    .clipped()
            }
        )
    }
}

#Preview("Card") {
    CardAdLayout(ad: .previewFixture(size: .card), onCTA: {})
        .padding()
}
