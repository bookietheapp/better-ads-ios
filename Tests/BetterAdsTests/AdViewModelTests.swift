import Foundation
import XCTest
@testable import BetterAds

@MainActor
final class AdViewModelTests: XCTestCase {
    private let adType = TestFixtures.bannerAdType
    private let baseURL = URL(string: "https://ads.example.com")!

    func testLoad_fetchesAndExposesAd() async throws {
        let http = MockHTTPClient()
        await http.enqueue(statusCode: 200, json: TestFixtures.sampleAdJSON)
        let client = makeClient(http: http)
        let viewModel = AdViewModel(client: client, type: adType)

        await viewModel.loadIfNeeded()

        guard case let .loaded(ad) = viewModel.state else {
            return XCTFail("Expected loaded state, got \(viewModel.state)")
        }
        XCTAssertEqual(ad.brand, "Sample Brand")
        XCTAssertEqual(ad.format, .banner)
    }

    func testImpression_trackedOnceOnAppear() async {
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
