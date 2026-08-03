import Foundation

/// Minimal HTTP abstraction so the SDK stays testable without third-party deps.
protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            // Keep cancellation as-is so view `.task` teardown does not become a hard failure.
            throw CancellationError()
        } catch {
            throw BetterAdsError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw BetterAdsError.invalidResponse
        }

        return (data, http)
    }
}
