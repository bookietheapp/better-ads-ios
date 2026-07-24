import Foundation
import XCTest
@testable import BetterAds

final class BetterAdsTests: XCTestCase {
    private let adType = TestFixtures.bannerAdType
    private let baseURL = URL(string: "https://ads.example.com")!

    // MARK: - Fetch

    func testFetchAd_successDecodesBookieShapedModel() async throws {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)

        let client = makeClient(http: http)
        let ad = try await client.fetchAd(type: adType)

        XCTAssertEqual(ad.campaignId, "sample-campaign-01")
        XCTAssertEqual(ad.size, "banner")
        XCTAssertEqual(ad.format, .banner)
        XCTAssertEqual(ad.brand, "Sample Brand")
        XCTAssertEqual(ad.backgroundColor, "#CC96FF")
        XCTAssertEqual(ad.textColor, "#000000")
        XCTAssertEqual(ad.headline, "Sample Brand")
        XCTAssertEqual(ad.cta.title, "Learn more")
        XCTAssertEqual(ad.cta.ctaButtonColor, "#FFFFFF")
        XCTAssertEqual(ad.cta.ctaTitleColor, "#000000")
        XCTAssertEqual(ad.cta.action.type, .url)
        XCTAssertEqual(ad.cta.action.value, TestFixtures.sampleCTAValue)
        XCTAssertEqual(
            ad.images.hero.url(for: 2)?.absoluteString,
            "https://cdn.example.com/diana.k@example.org"
        )

        let requests = await http.recordedRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].method, "GET")
        XCTAssertEqual(requests[0].url?.absoluteString, "https://ads.example.com/ads/banner")
        XCTAssertEqual(requests[0].headers["Accept-Language"], "en_US")
        XCTAssertEqual(requests[0].headers["X-API-Key"], "test-key")
    }

    func testFetchAd_unknownTypeReturnsTypedError() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 404, json: #"{"error":"unknown_ad_type"}"#)

        let client = makeClient(http: http)

        do {
            _ = try await client.fetchAd(type: AdType("does_not_exist"))
            XCTFail("Expected unknownAdType error")
        } catch let error as BetterAdsError {
            XCTAssertEqual(error, .unknownAdType(AdType("does_not_exist")))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchAd_errorResponseMapsToHTTPStatus() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 500, json: #"{"error":"boom"}"#)

        let client = makeClient(http: http)

        do {
            _ = try await client.fetchAd(type: adType)
            XCTFail("Expected httpStatus error")
        } catch let BetterAdsError.httpStatus(code, body) {
            XCTAssertEqual(code, 500)
            XCTAssertEqual(body, #"{"error":"boom"}"#)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Analytics

    func testTrackImpression_postsCorrectPayload() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 204, json: "")

        let client = makeClient(http: http)
        client.trackImpression(for: adType)

        let requests = await http.recordedRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].method, "POST")
        XCTAssertEqual(
            requests[0].url?.absoluteString,
            "https://ads.example.com/ads/banner/impressions"
        )
        XCTAssertEqual(requests[0].headers["Content-Type"], "application/json")
        XCTAssertEqual(requests[0].headers["X-API-Key"], "test-key")

        let json = try! XCTUnwrap(decodeJSONObject(requests[0].body))
        XCTAssertEqual(json["session_id"] as? String, "session-123")
        XCTAssertEqual(json["user_id"] as? String, "user-456")
        XCTAssertEqual(json["locale"] as? String, "en_US")
        XCTAssertNil(json["cta_value"])
    }

    func testTrackClick_postsCorrectPayload() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 204, json: "")

        let client = makeClient(http: http)
        client.trackClick(for: adType, ctaValue: TestFixtures.sampleCTAValue)

        let requests = await http.recordedRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].method, "POST")
        XCTAssertEqual(
            requests[0].url?.absoluteString,
            "https://ads.example.com/ads/banner/clicks"
        )

        let json = try! XCTUnwrap(decodeJSONObject(requests[0].body))
        XCTAssertEqual(json["session_id"] as? String, "session-123")
        XCTAssertEqual(json["user_id"] as? String, "user-456")
        XCTAssertEqual(json["locale"] as? String, "en_US")
        XCTAssertEqual(json["cta_value"] as? String, TestFixtures.sampleCTAValue)
    }

    func testTrackImpression_failureDoesNotThrow() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 503, json: #"{"error":"unavailable"}"#)

        let client = makeClient(http: http)
        client.trackImpression(for: adType)

        let requests = await http.recordedRequests
        XCTAssertEqual(requests.count, 1)
    }

    // MARK: - Helpers

    private func makeClient(http: MockHTTPClient) -> BetterAdsClient {
        BetterAdsClient(
            configuration: BetterAdsConfiguration(
                baseURL: baseURL,
                apiKey: "test-key",
                sessionID: "session-123",
                userID: "user-456",
                locale: Locale(identifier: "en_US")
            ),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )
    }

    private func decodeJSONObject(_ data: Data?) throws -> [String: Any] {
        let data = try XCTUnwrap(data)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
