import Foundation

/// Publisher-owned External Ad Id for keyed Serve. Empty / whitespace is treated as omitted.
enum ExternalAdId {
    static func normalize(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

/// Process-scoped creative cache so remounted placements can paint without a blank loading flash.
///
/// Unkeyed and keyed Serve results are stored separately so a keyed miss cannot reuse the
/// unkeyed pool (and vice versa).
final class AdResponseCache: @unchecked Sendable {
    private let lock = NSLock()
    private var adsByKey: [String: AdModel] = [:]

    func ad(for type: AdType, externalAdId: String? = nil) -> AdModel? {
        lock.lock()
        defer { lock.unlock() }
        return adsByKey[Self.key(type: type, externalAdId: externalAdId)]
    }

    func store(_ ad: AdModel, for type: AdType, externalAdId: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        adsByKey[Self.key(type: type, externalAdId: externalAdId)] = ad
    }

    func remove(for type: AdType, externalAdId: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        adsByKey[Self.key(type: type, externalAdId: externalAdId)] = nil
    }

    static func key(type: AdType, externalAdId: String?) -> String {
        if let id = ExternalAdId.normalize(externalAdId) {
            return "\(type.rawValue)#\(id)"
        }
        return type.rawValue
    }
}
