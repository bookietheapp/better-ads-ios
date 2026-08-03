import SwiftUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Loads a scale-appropriate remote ad image (Bookie `RemoteImage` role for ads).
struct AdRemoteImage<Placeholder: View, Content: View>: View {
    let url: URL?
    let pointSize: CGSize
    let placeholder: () -> Placeholder
    let imageContent: (Image) -> Content

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        imageContent(image)
                    case .failure:
                        placeholder()
                    case .empty:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
                // Avoid implicit fade transitions when the host recomposes the slot.
                .transaction { $0.animation = nil }
            } else {
                placeholder()
            }
        }
        .frame(width: pointSize.width, height: pointSize.height)
    }
}

enum AdDisplayScale {
    static var current: CGFloat {
        #if canImport(UIKit)
        UIScreen.main.scale
        #elseif canImport(AppKit)
        NSScreen.main?.backingScaleFactor ?? 2
        #else
        2
        #endif
    }
}
