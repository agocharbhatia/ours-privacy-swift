import XCTest
@testable import OursPrivacyKit

final class AttributionFragmentTests: XCTestCase {
    func testFragmentOnlyParametersDoNotBecomeAttributionOrVisitorIdentity() {
        for base in ["https://app.example.com/", "example://open"] {
            let url = base + "#details?ours_visitor_id=fragment-visitor&utm_source=fragment-source&gclid=fragment-click"
            let result = parseAttributionFromURL(url)

            XCTAssertNil(result.oursVisitorId)
            XCTAssertNil(result.utmParams)
            XCTAssertNil(result.clickIds)
            XCTAssertEqual(result.rawURL, url)
        }
    }

    func testQueryAttributionBeforeFragmentRemainsIntact() {
        let url = "example://open?ours_visitor_id=query-visitor&utm_source=spring%23sale&gclid=query-click"
            + "#details?ours_visitor_id=fragment-visitor&utm_source=fragment-source"
        let result = parseAttributionFromURL(url)

        XCTAssertEqual(result.oursVisitorId, "query-visitor")
        XCTAssertEqual(result.utmParams?["utm_source"], "spring#sale")
        XCTAssertEqual(result.clickIds?["gclid"], "query-click")
    }

    func testFragmentOnlyDeepLinkKeepsVisitorIdentityOnQueuedEvents() throws {
        let token = "fragment-test-\(UUID().uuidString)"
        let op = OursPrivacy(token: token)
        op.flushInterval = 0
        defer {
            op.trackingQueue.sync {}
            op.networkQueue.sync {}
            OursPrivacyPersistence.deleteUserDefaultsData(instanceName: token)
        }
        let visitorId = try XCTUnwrap(op.getVisitorId())

        op.trackDeepLink("example://open#details?ours_visitor_id=fragment-visitor&utm_source=fragment-source")
        op.track(event: "After Link")
        op.trackingQueue.sync {}

        XCTAssertEqual(op.getVisitorId(), visitorId)
        XCTAssertFalse(op.isManuallySetId)
        let events = op.oursprivacyPersistence.loadEntitiesInBatch(type: .events)
        XCTAssertEqual(events.compactMap { $0["event"] as? String }, ["$deep_link_opened", "After Link"])
        for event in events {
            XCTAssertEqual(event["visitor_id"] as? String, visitorId)
            let defaults = try XCTUnwrap(event["defaultProperties"] as? InternalProperties)
            XCTAssertNil(defaults["utm_source"])
        }
    }
}
