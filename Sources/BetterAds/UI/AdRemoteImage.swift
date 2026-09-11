import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
#endif

/// Loads a scale-appropriate remote ad image (Bookie `RemoteImage` role for ads).
///
/// Hits an in-memory cache first so lazy-list remounts do not flash the skeleton
/// after the creative has already downloaded.
struct AdRemoteImage<Placeholder: View, Content: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder
    let imageContent: (Image) -> Content

    @State private var loaded: PlatformImage?

    var body: some View {
        Group {
            if let display = resolvedImage {
                imageContent(swiftImage(display))
            } else if url != nil {
                placeholder()
                    .task(id: url) {
                        await load()
                    }
            } else {
                placeholder()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resolvedImage: PlatformImage? {
        if let loaded { return loaded }
        guard let url else { return nil }
        return AdImageMemoryCache.image(for: url)
    }

    @MainActor
    private func load() async {
        guard let url else { return }
        if let cached = AdImageMemoryCache.image(for: url) {
            loaded = cached
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = platformImage(from: data) else { return }
            AdImageMemoryCache.store(image, for: url)
            loaded = image
        } catch {
            // Keep the placeholder; a later remount can retry from cache or network.
        }
    }
}

fileprivate enum AdImageMemoryCache {
    private static let cache = NSCache<NSURL, AnyObject>()

    static func image(for url: URL) -> PlatformImage? {
        cache.object(forKey: url as NSURL) as? PlatformImage
    }

    static func store(_ image: PlatformImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
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

private func swiftImage(_ image: PlatformImage) -> Image {
    #if canImport(UIKit)
    Image(uiImage: image)
    #elseif canImport(AppKit)
    Image(nsImage: image)
    #endif
}

private func platformImage(from data: Data) -> PlatformImage? {
    #if canImport(UIKit)
    UIImage(data: data)
    #elseif canImport(AppKit)
    NSImage(data: data)
    #endif
}
