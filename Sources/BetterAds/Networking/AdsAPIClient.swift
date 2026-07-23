import Foundation

/// Builds and executes Better Ads backend requests.
struct AdsAPIClient: Sendable {
    private let configuration: BetterAdsConfiguration
    private let httpClient: any HTTPClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: BetterAdsConfiguration,
        httpClient: any HTTPClient,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
        self.encoder = encoder
        self.decoder = decoder
    }

    func fetchAd(type: AdType) async throws -> AdModel {
        let request = try makeRequest(
            path: "/ads/\(type.rawValue)",
            method: .get
        )

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

    func postImpression(type: AdType) async throws {
        let body = AnalyticsEnvelope(
            sessionID: configuration.sessionID,
            userID: configuration.userID,
            locale: configuration.locale.identifier,
            ctaValue: nil
        )
        try await post(path: "/ads/\(type.rawValue)/impressions", body: body)
    }

    func postClick(type: AdType, ctaValue: String) async throws {
        let body = AnalyticsEnvelope(
            sessionID: configuration.sessionID,
            userID: configuration.userID,
            locale: configuration.locale.identifier,
            ctaValue: ctaValue
        )
        try await post(path: "/ads/\(type.rawValue)/clicks", body: body)
    }

    // MARK: - Private

    private func post(path: String, body: AnalyticsEnvelope) async throws {
        var request = try makeRequest(path: path, method: .post)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await httpClient.send(request)
        guard (200 ... 299).contains(response.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8)
            throw BetterAdsError.httpStatus(code: response.statusCode, body: responseBody)
        }
    }

    private func makeRequest(path: String, method: HTTPMethod) throws -> URLRequest {
        guard var components = URLComponents(
            url: configuration.baseURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw BetterAdsError.invalidBaseURL
        }

        let normalizedBasePath = components.path.hasSuffix("/")
            ? String(components.path.dropLast())
            : components.path
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedBasePath + normalizedPath

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

        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        return request
    }
}

/// Analytics request body for impressions / clicks.
///
/// Assumption: backend accepts these snake_case fields. Confirm with ads backend team.
struct AnalyticsEnvelope: Encodable, Equatable {
    let sessionID: String?
    let userID: String?
    let locale: String
    let ctaValue: String?

    private enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case userID = "user_id"
        case locale
        case ctaValue = "cta_value"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(userID, forKey: .userID)
        try container.encode(locale, forKey: .locale)
        try container.encodeIfPresent(ctaValue, forKey: .ctaValue)
    }
}
