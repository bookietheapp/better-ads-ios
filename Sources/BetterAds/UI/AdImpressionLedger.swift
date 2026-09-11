import Foundation

/// Once-per-placement impression latch, independent of view-model lifetime
/// and of host session tokens.
///
/// Lazy lists dispose placements when they leave the window. Host `@State` /
/// `remember` UUIDs are often new on remount — those are **not** a new screen
/// visit. The latch is keyed only by placement + ad id so scroll off/on does
/// not re-count.
///
/// A new visit / pull-to-refresh must ``clear()`` or ``release(placement:adId:)``.
final class AdImpressionLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var keys: Set<String> = []

    /// - Returns: `true` if this is the first consume for the key.
    func consume(placement: String, adId: String) -> Bool {
        let key = Self.key(placement: placement, adId: adId)
        lock.lock()
        defer { lock.unlock() }
        if keys.contains(key) { return false }
        keys.insert(key)
        return true
    }

    func release(placement: String, adId: String) {
        let key = Self.key(placement: placement, adId: adId)
        lock.lock()
        defer { lock.unlock() }
        keys.remove(key)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        keys.removeAll()
    }

    private static func key(placement: String, adId: String) -> String {
        "\(placement)|\(adId)"
    }
}
