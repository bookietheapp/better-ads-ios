import Foundation

/// Process-scoped creative cache so remounted placements can paint without a blank loading flash.
final class AdResponseCache: @unchecked Sendable {
    private let lock = NSLock()
    private var adsByType: [String: AdModel] = [:]

    func ad(for type: AdType) -> AdModel? {
        lock.lock()
        defer { lock.unlock() }
        return adsByType[type.rawValue]
    }

    func store(_ ad: AdModel, for type: AdType) {
        lock.lock()
        defer { lock.unlock() }
        adsByType[type.rawValue] = ad
    }

    func remove(for type: AdType) {
        lock.lock()
        defer { lock.unlock() }
        adsByType[type.rawValue] = nil
    }
}
