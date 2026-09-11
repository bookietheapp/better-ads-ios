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

    func fetchAd(type: AdType, externalAdId: String? = nil) async throws -> AdModel {
        let path: String
        let queryItems: [URLQueryItem]
        let keyedId = ExternalAdId.normalize(externalAdId)
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
            if let keyedId {
                items.append(URLQueryItem(name: "externalAdId", value: keyedId))
            }
            if configuration.isTestEnv {
                items.append(URLQueryItem(name: "isTestEnv", value: "true"))
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

        if let url = request.url?.absoluteString {
            AdLog.info("GET \(url)")
        }

        let (data, response) = try await httpClient.send(request)

        switch response.statusCode {
        case 200 ... 299:
            do {
                let ad = try decoder.decode(AdModel.self, from: data)
                AdLog.info("serve \(response.statusCode) adId=\(ad.adId) size=\(ad.size)")
                return ad
            } catch {
                AdLog.info("serve decode failed: \(error)")
                throw BetterAdsError.decodingFailed(String(describing: error))
            }
        case 404:
            AdLog.info("serve 404 no ad size=\(type.rawValue) externalAdId=\(keyedId ?? "-")")
            throw BetterAdsError.unknownAdType(type)
        default:
            let body = String(data: data, encoding: .utf8)
            AdLog.info("serve \(response.statusCode) size=\(type.rawValue) body=\(body ?? "")")
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
            request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Api-Key")
        }

        if let token = await authProvider?.bearerAccessToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }
}
