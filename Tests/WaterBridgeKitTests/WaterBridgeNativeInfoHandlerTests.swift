import XCTest
import WaterBridgeCore
@testable import WaterBridgeKit

final class WaterBridgeNativeInfoHandlerTests: XCTestCase {
    @MainActor
    func testResponseDataContract() throws {
        let message = WaterBridgeMessage(
            channel: "Bridge",
            body: "water://nativeInfo",
            sourceURL: nil
        )

        let response = try XCTUnwrap(
            WaterBridgeNativeInfoHandler.handle(message) as? [String: Any]
        )
        let data = try XCTUnwrap(response["data"] as? [String: Any])
        let appVersion = try XCTUnwrap(
            data["appVersion"] as? [String: Any]
        )
        let deviceInfo = try XCTUnwrap(
            data["deviceInfo"] as? [String: Any]
        )

        XCTAssertNotNil(data["platform"] as? String)
        XCTAssertNotNil(data["osVersion"] as? String)
        XCTAssertNotNil(appVersion["versionCode"] as? Int)
        XCTAssertNotNil(appVersion["versionName"] as? String)
        XCTAssertNotNil(deviceInfo["modelNumber"] as? String)
    }
}
