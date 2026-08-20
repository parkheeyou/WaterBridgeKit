import XCTest
@testable import WaterBridgeCore

final class WaterDebugLogTests: XCTestCase {
    func testKeepsOnlyMostRecentEntries() {
        let center = WaterDebugLogCenter(maximumEntryCount: 2)

        center.record("first", category: .event)
        center.record("second", category: .api)
        center.record("third", category: .bridge)

        XCTAssertEqual(
            center.entries().map(\.message),
            ["second", "third"]
        )
    }

    func testClearAndExportText() {
        let center = WaterDebugLogCenter(maximumEntryCount: 10)
        center.record(
            "GET /profile -> 200",
            category: .api,
            level: .info,
            timestamp: Date(timeIntervalSince1970: 0)
        )

        let exported = center.exportText()
        XCTAssertTrue(exported.contains("[API][INFO] GET /profile -> 200"))

        center.clear()
        XCTAssertTrue(center.entries().isEmpty)
    }
}
