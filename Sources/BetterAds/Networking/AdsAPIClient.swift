import Foundation

/// Builds and executes Better Ads backend requests.
struct AdsAPIClient: @unchecked Sendable {
    private let configuration: BetterAdsConfiguration
    private let identity: BetterAdsIdentityStore
    private let httpClient: any HTTPClient
    private let authProvider: (any BetterAdsAuthProviding)?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: BetterAdsConfiguration,
        identity: BetterAdsIdentityStore,
        httpClient: any HTTPClient,
        authProvider: (any BetterAdsAuthProviding)? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.identity = identity
        self.httpClient = httpClient
        self.authProvider = authProvider
        self.encoder = encoder
        self.decoder = decoder
    }

    func fetchAd(type: AdType) async throws -> AdModel {
        let path: String
        let queryItems: [URLQueryItem]
        switch configuration.contentMode {
        case .bookieGetAd:
            path = "/getAd"
            queryItems = [URLQueryItem(name: "size", value: type.rawValue)]
        case .serveV1:
            path = "/api/v1/serve"
            var items = [URLQueryItem(name: "size", value: type.rawValue)]
            // Transitional: backend resolves the app from API key once auth ships.
            if let appName = configuration.appName, !appName.isEmpty {
                items.insert(URLQueryItem(name: "app", value: appName), at: 0)
            }
            queryItems = items
        case .dedicatedAPI:
            path = "/ads/\(type.rawValue)"
            queryItems = []
        case .fixture:
            // Handled by `FixtureBetterAdsContentProvider` — should not reach here.
            throw BetterAdsError.transport("Fixture mode does not use HTTP fetch")
        }

        let request = try await makeRequest(
            path: path,
            method: .get,
            queryItems: queryItems
        )

        #if DEBUG
        if let url = request.url?.absoluteString {
            print("[BetterAds] GET \(url)")
        }
        #endif

        let (data, response) = try await httpClient.send(request)

        switch response.statusCode {
        case 200 ... 299:
            do {
                return try decoder.decode(AdModel.self, from: data)
            } catch {
                throw BetterAdsError.decodingFailed(String(describing: error))
            }
        case 404:
            throw BetterAdsError.unknownAdType(type)
        default:
            let body = String(data: data, encoding: .utf8)
            throw BetterAdsError.httpStatus(code: response.statusCode, body: body)
        }
    }

    func postEvents(_ events: [AdEvent]) async throws -> EventsPostResult {
        let body = EventsRequestBody(events: events)
        var request = try await makeRequest(path: BetterAdsEndpoints.eventsPath, method: .post)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await httpClient.send(request)
        switch response.statusCode {
        case 200 ... 299:
            do {
                let decoded = try decoder.decode(EventsAPIResponse.self, from: data)
                return EventsPostResult.from(decoded)
            } catch {
                throw BetterAdsError.decodingFailed(String(describing: error))
            }
        default:
            let body = String(data: data, encoding: .utf8)
            throw BetterAdsError.httpStatus(code: response.statusCode, body: body)
        }
    }

    // MARK: - Private

    private struct EventsRequestBody: Encodable {
        let events: [AdEvent]
    }

    private func makeRequest(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = []
    ) async throws -> URLRequest {
        guard let baseURL = configuration.resolvedBaseURL,
              var components = URLComponents(
                url: baseURL,
                resolvingAgainstBaseURL: false
              )
        else {
            throw BetterAdsError.invalidBaseURL
        }

        let normalizedBasePath = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedBasePath + normalizedPath
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw BetterAdsError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            configuration.locale.identifier,
            forHTTPHeaderField: "Accept-Language"
        )

        if !configuration.apiKey.isEmpty {
            request.setValue(configuration.apiKey, forHTTPHeaderField: "X-API-Key")
        }

        if let token = await authProvider?.bearerAccessToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}
