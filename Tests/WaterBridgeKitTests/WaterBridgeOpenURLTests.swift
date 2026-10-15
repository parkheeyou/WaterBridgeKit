import Foundation
import XCTest
@testable import WaterBridgeKit

final class WaterBridgeOpenURLTests: XCTestCase {
    @MainActor
    func testQueryRoutesDecodeURLOnceAndOpenCorrectDestination() throws {
        let target = "https://example.com/a%2Fb?q=one&next=two#detail"
        for (api, expected) in [("openSafari", WaterBridgeWebTarget.safari), ("openWebView", .webView)] {
            var opened: WaterBridgeWebDestination?
            let router = WaterBridgeRouter(configuration: .init(), onOpenRequested: { opened = $0; return true })
            var components = URLComponents(string: "water://\(api)")!
            components.queryItems = [URLQueryItem(name: "url", value: target)]
            let message = makeMessage(components.string!)
            XCTAssertEqual(message.api, "water://\(api)")
            XCTAssertEqual(message.queryItems.first?.value, target)
            XCTAssertEqual(code(router.response(for: message)), "0000")
            XCTAssertEqual(opened?.target, expected)
            XCTAssertEqual(opened?.url.absoluteString, target)
        }
    }

    @MainActor
    func testJSONPayloadAndLegacyParamsAreSupported() {
        for key in ["data", "payload", "params"] {
            var opened: URL?
            let router = WaterBridgeRouter(configuration: .init(), onOpenRequested: { opened = $0.url; return true })
            let message = makeMessage(["api": "water://openWebView", key: ["url": "https://example.com/page"]])
            XCTAssertEqual(code(router.response(for: message)), "0000")
            XCTAssertEqual(opened?.absoluteString, "https://example.com/page")
        }
    }

    @MainActor
    func testUnsafeMalformedAndMissingURLsNeverOpen() {
        var openings = 0
        let router = WaterBridgeRouter(configuration: .init(), onOpenRequested: { _ in openings += 1; return true })
        for value in ["", "/relative", "javascript:alert(1)", "file:///tmp/test.html", "data:text/plain,test", "water://exit", "https://user:secret@example.com", "https://", "https://exa mple.com", "https://example.com/%ZZ"] {
            let message = makeMessage(["api": "water://openSafari", "data": ["url": value]])
            XCTAssertEqual(code(router.response(for: message)), "9999", value)
        }
        XCTAssertEqual(code(router.response(for: makeMessage("water://openWebView"))), "9999")
        XCTAssertEqual(code(router.response(for: makeMessage("water://openWebView?url=https%3A%2F%2Fexample.com&url=https%3A%2F%2Fother.test"))), "9999")
        XCTAssertEqual(openings, 0)
    }

    @MainActor
    func testConflictingOrNonStringURLIsRejected() {
        let router = WaterBridgeRouter(configuration: .init(), onOpenRequested: { _ in XCTFail("Should not open"); return true })
        let conflicting = makeMessage(["api": "water://openSafari?url=https%3A%2F%2Fexample.com", "data": ["url": "https://other.test"]])
        XCTAssertEqual(code(router.response(for: conflicting)), "9999")
        XCTAssertEqual(code(router.response(for: makeMessage(["api": "water://openWebView", "data": ["url": 123]]))), "9999")
    }

    @MainActor
    func testFailedPresentationAndCustomOverrides() {
        let unavailable = WaterBridgeRouter(configuration: .init(), onOpenRequested: { _ in false })
        let message = makeMessage(["api": "water://openWebView", "data": ["url": "https://example.com"]])
        XCTAssertEqual(code(unavailable.response(for: message)), "9999")
        var overrides = 0
        let custom = WaterBridgeRouter(configuration: .init(additionalRoutes: [
            WaterBridgeRoute(api: "water://openWebView", version: 2) { _ in
                overrides += 1
                return WaterBridgeResponse.success(data: [:]).value
            }
        ]), onOpenRequested: { _ in XCTFail("Override must suppress default UI"); return false })
        XCTAssertEqual(code(custom.response(for: message)), "0000")
        XCTAssertEqual(overrides, 1)
    }

    @MainActor
    func testRouteListIncludesBothAPIs() throws {
        let router = WaterBridgeRouter(configuration: .init())
        let response = try XCTUnwrap(router.response(for: makeMessage("water://routeApiList")) as? [String: Any])
        let routes = try XCTUnwrap(response["data"] as? [[String: Any]])
        for api in ["water://openSafari", "water://openWebView"] {
            XCTAssertEqual(routes.first(where: { $0["api"] as? String == api })?["version"] as? Int, 1)
        }
    }

    private func makeMessage(_ body: Any) -> WaterBridgeMessage {
        WaterBridgeMessage(channel: "Bridge", body: body, sourceURL: nil)
    }

    private func code(_ response: Any) -> String? {
        ((response as? [String: Any])?["status"] as? [String: String])?["code"]
    }
}

#if canImport(UIKit) && canImport(WebKit)
final class WaterBridgeWebNavigationTests: XCTestCase {
    @MainActor
    func testWebPresentationAndDismissalAllowNextRequest() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let model = WaterBridgeWebNavigation(openExternal: { _ in XCTFail("Must stay in app"); return false })
        XCTAssertTrue(model.request(.init(target: .webView, url: url)))
        XCTAssertEqual(model.webDestination?.url, url)
        XCTAssertFalse(model.request(.init(target: .webView, url: url)))
        model.webDestination = nil
        XCTAssertTrue(model.request(.init(target: .webView, url: url)))
    }

    @MainActor
    func testExternalOpenFailureIsDisplayed() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        var opened: URL?
        let model = WaterBridgeWebNavigation(openExternal: { opened = $0; return false })
        XCTAssertTrue(model.request(.init(target: .safari, url: url)))
        XCTAssertFalse(model.request(.init(target: .safari, url: url)))
        for _ in 0..<100 {
            if model.errorMessage != nil { break }
            await Task.yield()
        }
        XCTAssertEqual(opened, url)
        XCTAssertNotNil(model.errorMessage)
    }
}
#endif
