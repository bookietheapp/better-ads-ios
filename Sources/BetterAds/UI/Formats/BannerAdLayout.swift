import SwiftUI

/// Bookie-parity banner placement (`PlacementAdBannerView`).
struct BannerAdLayout: View {
    let ad: AdModel
    let onCTA: () -> Void

    /// Figma: Canela Text Medium 14 / leading 20 / tracking -0.28.
    private static let descriptionFontSize: CGFloat = 14
    private static let descriptionLineHeight: CGFloat = 20
    private static let descriptionTracking: CGFloat = -0.28

    private var descriptionLineSpacing: CGFloat {
        // Approximate Canela medium line height for system serif.
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
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HStack {
                    Spacer(minLength: 0)
                    heroImage
                }

                leftColumn(maxTextWidth: geometry.size.width * 0.5)

                AdAdvertisementLabel(style: .short)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: AdLayoutMetrics.bannerHeight)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AdLayoutMetrics.cornerRadius, style: .continuous))
    }

    private func leftColumn(maxTextWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            headlineView

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
            .fixedSize(horizontal: false, vertical: true)

            Button(action: onCTA) {
                Text(ad.cta.title)
                    .font(AdTypography.bodyHeavy(size: 13))
                    .lineSpacing(4)
                    .foregroundStyle(buttonTitleColor)
                    .padding(.horizontal, 16)
                    .frame(minWidth: 102)
                    .frame(height: 31)
                    .background(buttonBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: maxTextWidth, alignment: .leading)
    }

    @ViewBuilder
    private var headlineView: some View {
        if let wordmarkURL = ad.images.icon.url(for: AdDisplayScale.current) {
            AdRemoteImage(
                url: wordmarkURL,
                pointSize: CGSize(width: 109, height: 17),
                placeholder: {
                    Text(ad.headline)
                        .font(AdTypography.serif(14))
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
            .frame(height: 17, alignment: .leading)
            .accessibilityLabel(ad.headline)
        } else {
            Text(ad.headline)
                .font(AdTypography.serif(14))
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

#Preview("Banner") {
    BannerAdLayout(ad: .previewFixture(size: .banner), onCTA: {})
        .padding()
}
