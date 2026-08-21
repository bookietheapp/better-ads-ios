import Foundation

protocol AdEventStore: Sendable {
    func load() -> [AdEvent]
    func save(_ events: [AdEvent])
}

final class InMemoryAdEventStore: AdEventStore, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [AdEvent] = []

    func load() -> [AdEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    func save(_ events: [AdEvent]) {
        lock.lock()
        defer { lock.unlock() }
        self.events = events
    }
}

final class UserDefaultsAdEventStore: AdEventStore, @unchecked Sendable {
    private static let defaultsKey = "com.betterads.pending_events"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [AdEvent] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return [] }
        return (try? decoder.decode([AdEvent].self, from: data)) ?? []
    }

    func save(_ events: [AdEvent]) {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? encoder.encode(events) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
