import Foundation
import XCTest
@testable import BetterAds

final class AdViewModelTests: XCTestCase {
    private let adType = TestFixtures.bannerAdType
    private let baseURL = URL(string: "https://ads.example.com")!

    @MainActor
    func testLoad_fetchesAndExposesAd() async throws {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        let client = makeClient(http: http)
        let viewModel = AdViewModel(client: client, type: adType)

        await viewModel.loadIfNeeded()

        guard case let .loaded(ad) = viewModel.state else {
            return XCTFail("Expected loaded state, got \(viewModel.state)")
        }
        XCTAssertEqual(ad.adId, "42")
        XCTAssertEqual(ad.format, .banner)
    }

    @MainActor
    func testLoadIfNeeded_doesNotRefetchWhenAlreadyLoaded() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        let client = makeClient(http: http)
        let viewModel = AdViewModel(client: client, type: adType)

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        let requests = await http.recordedRequests
        XCTAssertEqual(requests.filter { $0.method == "GET" }.count, 1)
    }

    @MainActor
    func testImpression_trackedOncePerViewModel() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        await http.enqueue(statusCode: 200, json: #"{"ok":true,"accepted":1,"rejected":[]}"#)
        let client = makeClient(http: http)
        let viewModel = AdViewModel(client: client, type: adType)

        await viewModel.loadIfNeeded()
        viewModel.trackImpressionIfNeeded()
        viewModel.trackImpressionIfNeeded()

        let requests = await http.recordedRequests
        let impressionCalls = requests.filter {
            $0.method == "POST" && $0.url?.path.hasSuffix("/events") == true
        }
        XCTAssertEqual(impressionCalls.count, 1)
    }

    @MainActor
    func testImpression_resetAllowsSecondTrack() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        await http.enqueue(statusCode: 200, json: #"{"ok":true,"accepted":1,"rejected":[]}"#)
        await http.enqueue(statusCode: 200, json: #"{"ok":true,"accepted":1,"rejected":[]}"#)
        let client = makeClient(http: http)
        let viewModel = AdViewModel(client: client, type: adType)

        await viewModel.loadIfNeeded()
        XCTAssertTrue(viewModel.trackImpressionIfNeeded(sessionID: "explore-1"))
        viewModel.resetImpressionEligibility()
        XCTAssertTrue(viewModel.trackImpressionIfNeeded(sessionID: "explore-1"))

        let requests = await http.recordedRequests
        let impressionCalls = requests.filter {
            $0.method == "POST" && $0.url?.path.hasSuffix("/events") == true
        }
        XCTAssertEqual(impressionCalls.count, 2)
    }

    @MainActor
    func testImpression_dedupedAcrossViewModelsInSameSession() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        await http.enqueue(statusCode: 200, json: #"{"ok":true,"accepted":1,"rejected":[]}"#)
        await http.enqueue(statusCode: 200, json: #"{"ok":true,"accepted":1,"rejected":[]}"#)
        let client = makeClient(http: http)
        let first = AdViewModel(client: client, type: adType)
        await first.loadIfNeeded()
        XCTAssertTrue(first.trackImpressionIfNeeded(sessionID: "explore-1"))

        let remounted = AdViewModel(client: client, type: adType)
        XCTAssertFalse(remounted.trackImpressionIfNeeded(sessionID: "explore-1"))
        XCTAssertFalse(remounted.trackImpressionIfNeeded(sessionID: "uuid-from-second-compose"))
        client.resetImpressionSession()
        XCTAssertTrue(remounted.trackImpressionIfNeeded(sessionID: "uuid-from-second-compose"))

        let requests = await http.recordedRequests
        let impressionCalls = requests.filter {
            $0.method == "POST" && $0.url?.path.hasSuffix("/events") == true
        }
        XCTAssertEqual(impressionCalls.count, 2)
    }

    @MainActor
    func testClick_tracksAndReturnsAction() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        await http.enqueue(statusCode: 200, json: #"{"ok":true,"accepted":1,"rejected":[]}"#)
        let client = makeClient(http: http)
        let viewModel = AdViewModel(client: client, type: adType)

        await viewModel.loadIfNeeded()
        let action = viewModel.handleClick()

        XCTAssertEqual(action?.type, .url)
        XCTAssertEqual(action?.value, TestFixtures.sampleCTAValue)

        let requests = await http.recordedRequests
        let clickCalls = requests.filter {
            $0.method == "POST" && $0.url?.path.hasSuffix("/events") == true
        }
        XCTAssertEqual(clickCalls.count, 1)

        let json = try! XCTUnwrap(decodeJSONObject(clickCalls[0].body))
        let event = try! XCTUnwrap((json["events"] as? [[String: Any]])?.first)
        XCTAssertEqual(event["cta_value"] as? String, TestFixtures.sampleCTAValue)
    }

    @MainActor
    func testKeyedMiss_failsEvenWhenPreviousCreativeWasShowing() async {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        await http.enqueue(statusCode: 404, json: #"{"error":"not_found"}"#)

        let client = BetterAdsClient(
            configuration: BetterAdsConfiguration(
                apiKey: "nos_test",
                contentMode: .serveV1,
                appName: "Bookie",
                locale: Locale(identifier: "en_US")
            ),
            httpClient: http,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )
        let viewModel = AdViewModel(
            client: client,
            type: adType,
            externalAdId: "book_of_the_week_de"
        )

        await viewModel.loadIfNeeded()
        guard case .loaded = viewModel.state else {
            return XCTFail("Expected loaded state, got \(viewModel.state)")
        }

        await viewModel.revalidate()
        guard case .failed = viewModel.state else {
            return XCTFail("Expected failed after keyed miss, got \(viewModel.state)")
        }

        let requests = await http.recordedRequests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy { $0.url?.absoluteString.contains("externalAdId=book_of_the_week_de") == true })
    }

    @MainActor
    func testImpression_notTrackedBeforeLoad() async {
        let http = MockHTTPClient()
        let client = makeClient(http: http)
        let viewModel = AdViewModel(client: client, type: adType)

        viewModel.trackImpressionIfNeeded()

        let requests = await http.recordedRequests
        XCTAssertTrue(requests.isEmpty)
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
            eventStore: InMemoryAdEventStore(),
            flushScheduler: SynchronousFlushScheduler.run,
            analyticsTaskRunner: ImmediateAnalyticsTaskRunner()
        )
    }

    private func decodeJSONObject(_ data: Data?) throws -> [String: Any] {
        let data = try XCTUnwrap(data)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }
}
