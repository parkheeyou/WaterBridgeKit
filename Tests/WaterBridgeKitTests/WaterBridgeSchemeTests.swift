import XCTest
@testable import WaterBridgeKit

final class WaterBridgeSchemeTests: XCTestCase {
    @MainActor
    func testCustomSchemeBuiltinsAndRouteList() throws {
        var alert: String?
        let router = WaterBridgeRouter(configuration: .init(scheme: " MyApp "), onAlertRequested: { alert = $0; return true })
        let message = WaterBridgeMessage(channel: "Bridge", body: "myapp://alert?message=hello", sourceURL: nil, scheme: "myapp")
        _ = router.response(for: message)
        XCTAssertEqual(alert, "hello")
        let registry = WaterBridgeRouteRegistry(scheme: "myapp")
        XCTAssertTrue(registry.descriptors.allSatisfy { $0.api.hasPrefix("myapp://") })
        XCTAssertNotNil(registry.route(for: "myapp://openWebView"))
        XCTAssertNil(registry.route(for: "water://alert"))
    }

    @MainActor
    func testAppCanOverrideCustomSchemeBuiltin() {
        var handled = false
        var defaultHandled = false
        let route = WaterBridgeRoute(api: "exit", version: 3) { _ in
            handled = true
            return "custom"
        }
        let router = WaterBridgeRouter(configuration: .init(scheme: "myapp", additionalRoutes: [route]), onExitRequested: { defaultHandled = true })
        _ = router.response(for: WaterBridgeMessage(channel: "Bridge", body: "myapp://exit", sourceURL: nil, scheme: "myapp"))
        XCTAssertTrue(handled)
        XCTAssertFalse(defaultHandled)
    }
    @MainActor
    func testOneNameOnlyRouteWorksAcrossSchemesAndListsCurrentAddress() throws {
        let route = WaterBridgeRoute(api: "appInfo", version: 7) { _ in "handled" }
        XCTAssertEqual(route.api, "appInfo")
        for scheme in ["water", "myapp", "test"] {
            let router = WaterBridgeRouter(configuration: .init(scheme: scheme, additionalRoutes: [route]))
            let message = WaterBridgeMessage(channel: "Bridge", body: "\(scheme)://appInfo", sourceURL: nil, scheme: scheme)
            XCTAssertEqual(router.response(for: message) as? String, "handled")
            let listMessage = WaterBridgeMessage(channel: "Bridge", body: "\(scheme)://routeApiList", sourceURL: nil, scheme: scheme)
            let response = try XCTUnwrap(router.response(for: listMessage) as? [String: Any])
            let list = try XCTUnwrap(response["data"] as? [[String: Any]])
            XCTAssertEqual(list.first(where: { $0["api"] as? String == "\(scheme)://appInfo" })?["version"] as? Int, 7)
            XCTAssertTrue(list.allSatisfy { ($0["api"] as? String)?.hasPrefix("\(scheme)://") == true })
        }
    }

    @MainActor
    func testAllBuiltinsUseNamesAndDispatchAcrossSchemes() throws {
        XCTAssertEqual(Set(WaterBridgeAPI.all.map(\.api)), Set(["routeApiList", "nativeInfo", "exit", "alert", "openSafari", "openWebView"]))
        for scheme in ["water", "test"] {
            var didExit = false
            var opened = 0
            var didAlert = false
            let router = WaterBridgeRouter(configuration: .init(scheme: scheme), onExitRequested: { didExit = true }, onOpenRequested: { _ in opened += 1; return true }, onAlertRequested: { _ in didAlert = true; return true })
            for api in ["exit", "alert?message=hello", "openSafari?url=https%3A%2F%2Fexample.com", "openWebView?url=https%3A%2F%2Fexample.com"] {
                _ = router.response(for: WaterBridgeMessage(channel: "Bridge", body: "\(scheme)://\(api)", sourceURL: nil, scheme: scheme))
            }
            XCTAssertTrue(didExit)
            XCTAssertTrue(didAlert)
            XCTAssertEqual(opened, 2)
        }
    }

    @MainActor
    func testLegacyRegistrationNormalizesNameAndOverridesByName() {
        let legacy = WaterBridgeRoute(api: "water://exit", version: 8) { _ in "legacy" }
        XCTAssertEqual(legacy.api, "exit")
        let registry = WaterBridgeRouteRegistry(scheme: "test", additionalRoutes: [legacy])
        XCTAssertEqual(registry.routes.filter { $0.api == "exit" }.count, 1)
        XCTAssertEqual(registry.route(for: "test://exit")?.version, 8)
        XCTAssertNil(registry.route(for: "water://exit"))
    }

}
