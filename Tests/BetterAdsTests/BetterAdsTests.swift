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
        XCTAssertEqual(requests[0].url?.absoluteString, "https://ads.example.com/getAd?size=banner")
        XCTAssertEqual(requests[0].headers["Accept-Language"], "en_US")
        XCTAssertEqual(requests[0].headers["X-API-Key"], "test-key")
    }

    func testFetchAd_serveV1_includesAppAndSizeQuery() async throws {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)

        let client = BetterAdsClient(
            configuration: BetterAdsConfiguration(
                apiKey: "",
                contentMode: .serveV1,
                appName: "Bookie",
                locale: Locale(identifier: "en_US")
            ),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )
        _ = try await client.fetchAd(type: adType)

        let requests = await http.recordedRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(
            requests[0].url?.absoluteString,
            BetterAdsEndpoints.serveV1BaseURL.appendingPathComponent("api/v1/serve")
                .absoluteString + "?app=Bookie&size=banner"
        )
        XCTAssertNil(requests[0].headers["X-API-Key"])
    }

    func testFetchAd_serveV1_omitsAppWhenAppNameNil_sendsApiKey() async throws {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)

        let client = BetterAdsClient(
            configuration: BetterAdsConfiguration(
                apiKey: "future-key",
                contentMode: .serveV1,
                appName: nil,
                locale: Locale(identifier: "en_US")
            ),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )
        _ = try await client.fetchAd(type: adType)

        let requests = await http.recordedRequests
        XCTAssertEqual(
            requests[0].url?.absoluteString,
            BetterAdsEndpoints.serveV1BaseURL.appendingPathComponent("api/v1/serve")
                .absoluteString + "?size=banner"
        )
        XCTAssertEqual(requests[0].headers["X-API-Key"], "future-key")
    }

    func testFetchAd_serveV1_ignoresHostBaseURL() async throws {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)

        let client = BetterAdsClient(
            configuration: BetterAdsConfiguration(
                apiKey: "",
                contentMode: .serveV1,
                baseURL: URL(string: "https://ads.example.com")!,
                appName: "Bookie",
                locale: Locale(identifier: "en_US")
            ),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )
        _ = try await client.fetchAd(type: adType)

        let requests = await http.recordedRequests
        XCTAssertTrue(
            requests[0].url?.absoluteString.hasPrefix(BetterAdsEndpoints.serveV1BaseURL.absoluteString) == true
        )
        XCTAssertFalse(requests[0].url?.absoluteString.contains("ads.example.com") == true)
    }

    func testFetchAd_fixtureMode_returnsSampleWithoutNetwork() async throws {
        let http = MockHTTPClient()
        let client = BetterAdsClient(
            configuration: .fixture(apiKey: "test-key"),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )

        let ad = try await client.fetchAd(format: .banner)
        XCTAssertEqual(ad.format, .banner)
        XCTAssertEqual(ad.brand, "Sample Brand")

        let requests = await http.recordedRequests
        XCTAssertTrue(requests.isEmpty)
    }

    func testFixtureMode_skipsAnalyticsNetworkCalls() async {
        let http = MockHTTPClient()
        let client = BetterAdsClient(
            configuration: .fixture(apiKey: "test-key"),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )

        client.trackImpression(for: adType)
        client.trackClick(for: adType, ctaValue: TestFixtures.sampleCTAValue)

        let requests = await http.recordedRequests
        XCTAssertTrue(requests.isEmpty)
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
        XCTAssertEqual(json["device_id"] as? String, "device-789")
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
        XCTAssertEqual(json["device_id"] as? String, "device-789")
        XCTAssertEqual(json["session_id"] as? String, "session-123")
        XCTAssertEqual(json["user_id"] as? String, "user-456")
        XCTAssertEqual(json["locale"] as? String, "en_US")
        XCTAssertEqual(json["cta_value"] as? String, TestFixtures.sampleCTAValue)
    }

    func testTrackImpression_loggedOut_omitsUserIdKeepsDeviceId() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 204, json: "")

        let client = BetterAdsClient(
            configuration: BetterAdsConfiguration(
                apiKey: "test-key",
                contentMode: .bookieGetAd,
                baseURL: baseURL,
                sessionID: "session-123",
                userID: nil,
                deviceID: "device-789",
                locale: Locale(identifier: "en_US")
            ),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )
        client.trackImpression(for: adType)

        let requests = await http.recordedRequests
        let json = try! XCTUnwrap(decodeJSONObject(requests[0].body))
        XCTAssertEqual(json["device_id"] as? String, "device-789")
        XCTAssertEqual(json["session_id"] as? String, "session-123")
        XCTAssertNil(json["user_id"])
    }

    func testSetUserID_updatesPayloadAndRotatesSessionOnLogout() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 204, json: "")
        await http.enqueue(statusCode: 204, json: "")

        let client = BetterAdsClient(
            configuration: BetterAdsConfiguration(
                apiKey: "test-key",
                contentMode: .bookieGetAd,
                baseURL: baseURL,
                // SDK-owned session (nil) so logout rotates it.
                sessionID: nil,
                userID: "user-456",
                deviceID: "device-789",
                locale: Locale(identifier: "en_US")
            ),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )

        client.trackImpression(for: adType)
        var requests = await http.recordedRequests
        let loggedIn = try! XCTUnwrap(decodeJSONObject(requests[0].body))
        XCTAssertEqual(loggedIn["user_id"] as? String, "user-456")
        let sessionWhileLoggedIn = try! XCTUnwrap(loggedIn["session_id"] as? String)

        client.setUserID(nil)
        client.trackImpression(for: adType)
        requests = await http.recordedRequests
        let loggedOut = try! XCTUnwrap(decodeJSONObject(requests[1].body))
        XCTAssertNil(loggedOut["user_id"])
        XCTAssertEqual(loggedOut["device_id"] as? String, "device-789")
        let sessionAfterLogout = try! XCTUnwrap(loggedOut["session_id"] as? String)
        XCTAssertNotEqual(sessionWhileLoggedIn, sessionAfterLogout)
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
                apiKey: "test-key",
                contentMode: .bookieGetAd,
                baseURL: baseURL,
                sessionID: "session-123",
                userID: "user-456",
                deviceID: "device-789",
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
