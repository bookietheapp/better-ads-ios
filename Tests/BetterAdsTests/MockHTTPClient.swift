import Foundation
@testable import BetterAds

actor MockHTTPClient: HTTPClient {
    struct RecordedRequest: Equatable {
        let method: String?
        let url: URL?
        let headers: [String: String]
        let body: Data?
    }

    private enum EnqueuedResponse {
        case success(statusCode: Int, data: Data, headerFields: [String: String]?)
        case failure(Error)
    }

    private var responses: [EnqueuedResponse] = []
    private(set) var recordedRequests: [RecordedRequest] = []

    func enqueue(
        statusCode: Int,
        json: String,
        headerFields: [String: String]? = ["Content-Type": "application/json"]
    ) {
        responses.append(
            .success(statusCode: statusCode, data: Data(json.utf8), headerFields: headerFields)
        )
    }

    func enqueueError(_ error: Error) {
        responses.append(.failure(error))
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

        guard !responses.isEmpty else {
            throw BetterAdsError.transport("MockHTTPClient has no enqueued responses")
        }

        switch responses.removeFirst() {
        case let .success(statusCode, data, headerFields):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headerFields
            )!
            return (data, response)
        case let .failure(error):
            throw error
        }
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
