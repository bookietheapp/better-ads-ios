import SwiftUI

/// Color + copy helpers ported from Bookie `PlacementAdFormatting`.
enum AdFormatting {
    static func swiftUIColor(fromHex hex: String, fallback: Color) -> Color {
        guard let color = parseHex(hex) else { return fallback }
        return color
    }

    /// Supports `*emphasis*` markers in ad description copy (Bookie parity).
    static func attributedDescription(
        _ text: String,
        baseColor: Color,
        baseFont: Font,
        emphasisFont: Font
    ) -> AttributedString {
        var result = AttributedString()
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "*" {
                let afterOpen = text.index(after: index)
                if let closeIndex = text[afterOpen...].firstIndex(of: "*") {
                    let emphasisText = String(text[afterOpen..<closeIndex])
                    var segment = AttributedString(emphasisText)
                    segment.font = emphasisFont
                    segment.foregroundColor = baseColor
                    result.append(segment)
                    index = text.index(after: closeIndex)
                    continue
                }
            }

            let nextMarker = text[index...].firstIndex(of: "*") ?? text.endIndex
            let plain = String(text[index..<nextMarker])
            if !plain.isEmpty {
                var segment = AttributedString(plain)
                segment.font = baseFont
                segment.foregroundColor = baseColor
                result.append(segment)
            }
            index = nextMarker
        }

        return result
    }

    private static func parseHex(_ hex: String) -> Color? {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return nil
        }
        let red = Double((value & 0xFF0000) >> 16) / 255.0
        let green = Double((value & 0x00FF00) >> 8) / 255.0
        let blue = Double(value & 0x0000FF) / 255.0
        return Color(red: red, green: green, blue: blue)
    }
}

enum AdLayoutMetrics {
    static let advertisementLabelInset: CGFloat = 8
    static let advertisementLabelCornerRadius: CGFloat = 4
    static let advertisementLabelBackgroundOpacity: CGFloat = 0.72
    static let cornerRadius: CGFloat = 12
    static let bannerHeight: CGFloat = 164
}

/// Fallback typography approximating Bookie Canela / design-system sizes.
///
/// Exact Canela faces live in the Bookie app; the SDK uses system serif at the
/// same point sizes, tracking, and line heights so layout geometry matches.
enum AdTypography {
    static func serif(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func serifItalic(_ size: CGFloat) -> Font {
        // System italic serif approximation for `*emphasis*` spans.
        .system(size: size, weight: .medium, design: .serif).italic()
    }

    static func bodyHeavy(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func caption(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
}
