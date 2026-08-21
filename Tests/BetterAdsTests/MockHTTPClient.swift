import Foundation
@testable import BetterAds

actor MockHTTPClient: HTTPClient {
    struct RecordedRequest: Equatable {
        let method: String?
        let url: URL?
        let headers: [String: String]
        let body: Data?
    }

    private var handlers: [(URLRequest) async throws -> (Data, HTTPURLResponse)] = []
    private(set) var recordedRequests: [RecordedRequest] = []

    func enqueue(
        statusCode: Int,
        json: String,
        headerFields: [String: String]? = ["Content-Type": "application/json"]
    ) {
        let data = Data(json.utf8)
        handlers.append { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headerFields
            )!
            return (data, response)
        }
    }

    func enqueueError(_ error: Error) {
        handlers.append { _ in
            throw error
        }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let headers = request.allHTTPHeaderFields ?? [:]
        recordedRequests.append(
            RecordedRequest(
                method: request.httpMethod,
                url: request.url,
                headers: headers,
                body: request.httpBody
            )
        )

        guard !handlers.isEmpty else {
            throw BetterAdsError.transport("MockHTTPClient has no enqueued responses")
        }

        let handler = handlers.removeFirst()
        return try await handler(request)
    }
}

/// Runs async flush work inline so tests can await HTTP side effects.
enum SynchronousFlushScheduler {
    static func run(_ operation: @escaping @Sendable () async -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await operation()
            semaphore.signal()
        }
        semaphore.wait()
    }
}

/// Runs analytics operations inline so tests can await completion.
struct ImmediateAnalyticsTaskRunner: AnalyticsTaskRunner {
    func run(_ operation: @escaping @Sendable () async -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await operation()
            semaphore.signal()
        }
        semaphore.wait()
    }
}
