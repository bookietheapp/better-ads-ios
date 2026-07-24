import SwiftUI

/// Bookie-parity compact placement (`PlacementAdCompactView`).
struct CompactAdLayout: View {
    let ad: AdModel
    let onCTA: () -> Void

    private var backgroundColor: Color {
        AdFormatting.swiftUIColor(fromHex: ad.backgroundColor, fallback: Color.gray.opacity(0.2))
    }

    private var textColor: Color {
        AdFormatting.swiftUIColor(fromHex: ad.textColor, fallback: Color.black.opacity(0.8))
    }

    private var buttonBackground: Color {
        AdFormatting.swiftUIColor(fromHex: ad.cta.ctaButtonColor, fallback: .white)
    }

    private var buttonTitleColor: Color {
        AdFormatting.swiftUIColor(fromHex: ad.cta.ctaTitleColor, fallback: .black)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 8) {
                heroImage
                textColumn
                ctaButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)

            AdAdvertisementLabel(style: .short)
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AdLayoutMetrics.cornerRadius, style: .continuous))
    }

    private var heroImage: some View {
        AdRemoteImage(
            url: ad.images.hero.url(for: AdDisplayScale.current),
            pointSize: CGSize(width: 50, height: 53),
            placeholder: {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: 50, height: 53)
            },
            imageContent: { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 53)
                    .clipped()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            headlineView

            Text(
                AdFormatting.attributedDescription(
                    ad.description,
                    baseColor: textColor.opacity(0.8),
                    baseFont: AdTypography.caption(size: 12),
                    emphasisFont: AdTypography.serifItalic(12)
                )
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var headlineView: some View {
        if let wordmarkURL = ad.images.icon.url(for: AdDisplayScale.current) {
            AdRemoteImage(
                url: wordmarkURL,
                pointSize: CGSize(width: 84, height: 13),
                placeholder: {
                    Text(ad.headline)
                        .font(AdTypography.serif(17))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                },
                imageContent: { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: 13)
                }
            )
            .frame(height: 13, alignment: .leading)
            .accessibilityLabel(ad.headline)
        } else {
            Text(ad.headline)
                .font(AdTypography.serif(17))
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
    }

    private var ctaButton: some View {
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
}

#Preview("Compact") {
    CompactAdLayout(ad: .previewFixture(size: .compact), onCTA: {})
        .padding()
}
