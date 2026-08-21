import Foundation
import os

/// Schedules async flush work (default: detached `Task`; tests may run inline).
typealias AdEventFlushScheduler = (@escaping @Sendable () async -> Void) -> Void

/// Buffers ad events locally and flushes batches to `POST /api/v1/events`.
final class AdEventQueue: @unchecked Sendable {
    static let maxBatchSize = 500

    private let store: AdEventStore
    private let postEvents: @Sendable ([AdEvent]) async throws -> EventsPostResult
    private let flushScheduler: AdEventFlushScheduler
    private let logger: Logger
    private let lock = NSLock()
    private var isFlushing = false
    private var authPaused = false

    init(
        store: AdEventStore = UserDefaultsAdEventStore(),
        postEvents: @escaping @Sendable ([AdEvent]) async throws -> EventsPostResult,
        scheduleFlush: @escaping AdEventFlushScheduler = { operation in
            Task { await operation() }
        },
        logger: Logger = Logger(subsystem: "com.betterads.sdk", category: "AdEventQueue")
    ) {
        self.store = store
        self.postEvents = postEvents
        self.flushScheduler = scheduleFlush
        self.logger = logger
    }

    func enqueue(_ event: AdEvent) {
        lock.lock()
        if authPaused {
            lock.unlock()
            logger.warning("Skipping event flush — API key rejected (401)")
            append(event)
            return
        }
        lock.unlock()

        append(event)
        scheduleFlush()
    }

    /// Attempts to flush pending events. Safe to call from tests.
    func flushNow() async {
        await flush()
    }

    /// Clears auth pause after the host fixes API key configuration.
    func resumeAfterAuthFailure() {
        lock.lock()
        authPaused = false
        lock.unlock()
        scheduleFlush()
    }

    var pendingCount: Int {
        store.load().count
    }

    // MARK: - Private

    private func append(_ event: AdEvent) {
        var pending = store.load()
        pending.append(event)
        store.save(pending)
    }

    private func scheduleFlush() {
        flushScheduler { await self.flush() }
    }

    private func flush() async {
        lock.lock()
        guard !isFlushing else {
            lock.unlock()
            return
        }
        guard !authPaused else {
            lock.unlock()
            return
        }
        isFlushing = true
        lock.unlock()

        defer {
            lock.lock()
            isFlushing = false
            lock.unlock()
        }

        while true {
            let batch = nextBatch()
            guard !batch.isEmpty else { return }

            do {
                let result = try await postEvents(batch)
                applySuccess(batch: batch, result: result)
            } catch let error as BetterAdsError {
                switch error {
                case let .httpStatus(code, _) where code == 401:
                    lock.lock()
                    authPaused = true
                    lock.unlock()
                    logger.error("Events flush paused — invalid App API key (401)")
                    return
                case let .httpStatus(code, _) where (400 ... 499).contains(code):
                    logger.error("Events flush dropped batch — client error \(code, privacy: .public)")
                    removeEvents(batch)
                    return
                default:
                    logger.warning("Events flush failed — will retry: \(String(describing: error), privacy: .public)")
                    return
                }
            } catch {
                logger.warning("Events flush failed — will retry: \(String(describing: error), privacy: .public)")
                return
            }

            // More than one batch worth may be queued.
            if nextBatch().isEmpty { return }
        }
    }

    private func nextBatch() -> [AdEvent] {
        Array(store.load().prefix(Self.maxBatchSize))
    }

    private func applySuccess(batch: [AdEvent], result: EventsPostResult) {
        let rejectedIndices = Set(result.rejected.map(\.index))
        let rejectedIds = Set(
            result.rejected.compactMap(\.eventId).map { $0.lowercased() }
        )

        let toRemove = batch.enumerated().compactMap { index, event -> AdEvent? in
            if rejectedIndices.contains(index) { return nil }
            if rejectedIds.contains(event.eventId.uuidString.lowercased()) { return nil }
            return event
        }

        removeEvents(toRemove)

        for rejection in result.rejected {
            logger.warning(
                "Rejected event at index \(rejection.index, privacy: .public): \(rejection.errors.joined(separator: ", "), privacy: .public)"
            )
        }
    }

    private func removeEvents(_ events: [AdEvent]) {
        guard !events.isEmpty else { return }
        let removeIds = Set(events.map { $0.eventId })
        var pending = store.load()
        pending.removeAll { removeIds.contains($0.eventId) }
        store.save(pending)
    }
}

struct EventsPostResult: Sendable, Equatable {
    let accepted: Int
    let rejected: [RejectedEventItem]
}

struct RejectedEventItem: Sendable, Equatable {
    let index: Int
    let eventId: String?
    let errors: [String]
}

struct EventsAPIResponse: Decodable {
    let ok: Bool
    let accepted: Int
    let rejected: [RejectedEventResponse]

    struct RejectedEventResponse: Decodable {
        let index: Int
        let eventId: String?
        let errors: [String]?

        private enum CodingKeys: String, CodingKey {
            case index
            case eventId = "event_id"
            case errors
        }
    }
}

extension EventsPostResult {
    static func from(_ response: EventsAPIResponse) -> EventsPostResult {
        EventsPostResult(
            accepted: response.accepted,
            rejected: response.rejected.map {
                RejectedEventItem(
                    index: $0.index,
                    eventId: $0.eventId,
                    errors: $0.errors ?? []
                )
            }
        )
    }
}
