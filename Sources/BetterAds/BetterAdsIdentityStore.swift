import Foundation

/// Owns ads identity used on impression/click payloads.
///
/// By default the SDK manages `device_id` (persisted) and `session_id` (process-scoped).
/// Hosts only need to call ``BetterAdsClient/setUserID(_:)`` when auth changes.
final class BetterAdsIdentityStore: @unchecked Sendable {
    private static let deviceIDDefaultsKey = "com.betterads.device_id"

    private let lock = NSLock()
    private let ownsSession: Bool
    private let deviceIDValue: String
    private var sessionIDValue: String
    private var userIDValue: String?

    init(
        deviceID: String?,
        sessionID: String?,
        userID: String?
    ) {
        self.deviceIDValue = Self.resolvedDeviceID(override: deviceID)
        self.ownsSession = sessionID == nil
        self.sessionIDValue = sessionID ?? UUID().uuidString
        self.userIDValue = userID
    }

    func setUserID(_ userID: String?) {
        lock.lock()
        defer { lock.unlock() }
        let previous = userIDValue
        userIDValue = userID
        // Logout / clear account → new visit session (only when SDK owns session id).
        if ownsSession, previous != nil, userID == nil {
            sessionIDValue = UUID().uuidString
        }
    }

    var snapshot: (deviceID: String, sessionID: String, userID: String?) {
        lock.lock()
        defer { lock.unlock() }
        return (deviceIDValue, sessionIDValue, userIDValue)
    }

    private static func resolvedDeviceID(override: String?) -> String {
        if let override = override?.trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return override
        }
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceIDDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        defaults.set(created, forKey: deviceIDDefaultsKey)
        return created
    }
}
