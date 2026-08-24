import SwiftUI

/// Bookie-parity banner placement (`PlacementAdBannerView`).
struct BannerAdLayout: View {
    let ad: AdModel
    let onCTA: () -> Void

    /// Figma: Canela Text Medium 14 / leading 20 / tracking -0.28.
    private static let descriptionFontSize: CGFloat = 14
    private static let descriptionLineHeight: CGFloat = 20
    private static let descriptionTracking: CGFloat = -0.28
    private static let horizontalPadding: CGFloat = 16
    private static let heroWidth: CGFloat = 205
    /// Headline and body copy stay in the left half; the CTA may extend over the hero.
    private static let textColumnWidthFraction: CGFloat = 0.5

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
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HStack {
                    Spacer(minLength: 0)
                    heroImage
                }

                contentColumn(totalWidth: geometry.size.width)

                AdAdvertisementLabel(style: .short)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: AdLayoutMetrics.bannerHeight)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AdLayoutMetrics.cornerRadius, style: .continuous))
    }

    private func contentColumn(totalWidth: CGFloat) -> some View {
        let textMaxWidth = totalWidth * Self.textColumnWidthFraction - Self.horizontalPadding
        let ctaMaxWidth = totalWidth - Self.horizontalPadding * 2

        return VStack(alignment: .leading, spacing: 12) {
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
            }
            .frame(maxWidth: textMaxWidth, alignment: .leading)

            Button(action: onCTA) {
                Text(ad.cta.title)
                    .font(AdTypography.bodyHeavy(size: 13))
                    .lineSpacing(4)
                    .foregroundStyle(buttonTitleColor)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .frame(minWidth: 102)
                    .frame(height: 31)
                    .background(buttonBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: ctaMaxWidth, alignment: .leading)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: ctaMaxWidth, alignment: .leading)
        .zIndex(1)
    }

    @ViewBuilder
    private var headlineView: some View {
        if let wordmarkURL = ad.images.icon.url(for: AdDisplayScale.current) {
            // Keep a blank wordmark slot while loading / if the asset fails (e.g. SVG).
            AdRemoteImage(
                url: wordmarkURL,
                pointSize: CGSize(width: 109, height: 17),
                placeholder: {
                    Color.clear
                        .frame(width: 109, height: 17)
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
        } else if !ad.headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(ad.headline)
                .font(AdTypography.serif(14))
                .foregroundStyle(textColor)
                .lineLimit(1)
        } else {
            Color.clear.frame(height: 17)
        }
    }

    private var heroImage: some View {
        AdRemoteImage(
            url: ad.images.hero.url(for: AdDisplayScale.current),
            pointSize: CGSize(width: Self.heroWidth, height: AdLayoutMetrics.bannerHeight),
            placeholder: {
                Color.clear
                    .frame(width: Self.heroWidth, height: AdLayoutMetrics.bannerHeight)
            },
            imageContent: { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.heroWidth, height: AdLayoutMetrics.bannerHeight)
                    .clipped()
            }
        )
        .frame(width: Self.heroWidth, height: AdLayoutMetrics.bannerHeight)
    }
}

#Preview("Banner") {
    BannerAdLayout(ad: .previewFixture(size: .banner), onCTA: {})
        .padding()
}
