import XCTest
@testable import WaterBridgeKit

final class WaterBridgeExitTests: XCTestCase {
    @MainActor
    func testExitRouteRequestsConfirmationAndAcknowledgesRequest() throws {
        var requests = 0
        let router = WaterBridgeRouter(configuration: .init(), onExitRequested: { requests += 1 })
        let response = try XCTUnwrap(router.response(for: message("water://exit")) as? [String: Any])
        let status = try XCTUnwrap(response["status"] as? [String: String])
        let data = try XCTUnwrap(response["data"] as? [String: Bool])
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(status["code"], "0000")
        XCTAssertEqual(data["confirmationRequired"], true)
    }

    @MainActor
    func testExitAppearsInRouteAPIList() throws {
        let router = WaterBridgeRouter(configuration: .init())
        let response = try XCTUnwrap(router.response(for: message("water://routeApiList")) as? [String: Any])
        let routes = try XCTUnwrap(response["data"] as? [[String: Any]])
        XCTAssertEqual(routes.first(where: { $0["api"] as? String == "water://exit" })?["version"] as? Int, 1)
    }

    @MainActor
    func testAppOverrideDoesNotTriggerBuiltInConfirmation() {
        var requests = 0
        var overrides = 0
        let router = WaterBridgeRouter(configuration: .init(additionalRoutes: [
            WaterBridgeRoute(api: "water://exit", version: 2) { _ in
                overrides += 1
                return WaterBridgeResponse.success(data: [:]).value
            }
        ]), onExitRequested: { requests += 1 })
        _ = router.response(for: message("water://exit"))
        XCTAssertEqual(overrides, 1)
        XCTAssertEqual(requests, 0)
    }

    @MainActor
    func testCancelDoesNotTerminateAndAllowsAnotherRequest() {
        var terminations = 0
        let confirmation = WaterBridgeExitConfirmation(terminate: { terminations += 1 })
        confirmation.request()
        XCTAssertTrue(confirmation.isPresented)
        confirmation.cancel()
        confirmation.confirm()
        XCTAssertFalse(confirmation.isPresented)
        XCTAssertEqual(terminations, 0)
        confirmation.request()
        XCTAssertTrue(confirmation.isPresented)
    }

    @MainActor
    func testRepeatedRequestAndSwiftUIAlertDismissalTerminateOnlyOnce() {
        var terminations = 0
        let confirmation = WaterBridgeExitConfirmation(terminate: { terminations += 1 })
        confirmation.confirm()
        XCTAssertEqual(terminations, 0)
        confirmation.request()
        confirmation.request()
        // SwiftUI alert 버튼을 누르면 binding이 action보다 먼저 false가 될 수 있습니다.
        confirmation.isPresented = false
        confirmation.confirm()
        confirmation.confirm()
        XCTAssertEqual(terminations, 1)
    }

    private func message(_ api: String) -> WaterBridgeMessage {
        WaterBridgeMessage(channel: "Bridge", body: api, sourceURL: nil)
    }
}
