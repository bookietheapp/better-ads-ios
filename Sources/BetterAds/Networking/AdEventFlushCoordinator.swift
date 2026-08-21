import Foundation

#if os(iOS)
import UIKit

/// Periodically and on app background, flushes the local ad-events queue.
final class AdEventFlushCoordinator: @unchecked Sendable {
    static let flushInterval: TimeInterval = 30

    private let queue: AdEventQueue
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(queue: AdEventQueue) {
        self.queue = queue
    }

    func start() {
        stop()

        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleFlush()
            },
            center.addObserver(
                forName: UIApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleFlush()
            },
        ]

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timer = Timer.scheduledTimer(withTimeInterval: Self.flushInterval, repeats: true) { [weak self] _ in
                self?.scheduleFlush()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }

    private func scheduleFlush() {
        Task {
            await queue.flushNow()
        }
    }
}
#endif
