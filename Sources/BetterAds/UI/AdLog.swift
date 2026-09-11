import Foundation

/// Console logs for host-app debugging (Xcode: filter `BetterAds`).
/// No-op in Release so production builds stay quiet.
enum AdLog {
    static func info(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[BetterAds] \(message())")
        #endif
    }
}
