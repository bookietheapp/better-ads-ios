import Foundation

#if canImport(UIKit)
import UIKit
import SafariServices
#endif

/// Opens CTA destinations. Owned by the SDK — host apps should not open ad URLs themselves.
enum AdActionHandler {
    @MainActor
    static func open(_ action: AdCTAAction) {
        let trimmed = action.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }

        // Serve payloads sometimes label app schemes as `type: url`. SFSafariViewController
        // only accepts http/https — route everything else (e.g. bookie://) as a deeplink.
        if shouldOpenInBrowser(url), action.type == .url {
            openExternalURL(url)
        } else {
            openDeeplink(url)
        }
    }

    /// HTTP(S) only — safe for `SFSafariViewController` / Custom Tabs.
    static func shouldOpenInBrowser(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    #if canImport(UIKit)
    @MainActor
    private static func openExternalURL(_ url: URL) {
        guard shouldOpenInBrowser(url) else {
            openDeeplink(url)
            return
        }
        if let presenter = topMostViewController() {
            let safari = SFSafariViewController(url: url)
            presenter.present(safari, animated: true)
        } else {
            UIApplication.shared.open(url)
        }
    }

    @MainActor
    private static func openDeeplink(_ url: URL) {
        UIApplication.shared.open(url)
    }

    @MainActor
    private static func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let window = scenes
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first(where: \.isKeyWindow)

        guard var controller = window?.rootViewController else { return nil }
        while let presented = controller.presentedViewController {
            controller = presented
        }
        return controller
    }
    #else
    @MainActor
    private static func openExternalURL(_ url: URL) {
        // macOS / non-UIKit: best-effort via NSWorkspace if available is out of scope for ads SDK.
    }

    @MainActor
    private static func openDeeplink(_ url: URL) {}
    #endif
}
