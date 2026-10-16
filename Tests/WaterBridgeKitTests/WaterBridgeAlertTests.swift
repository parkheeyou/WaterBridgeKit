import Foundation
import XCTest
@testable import WaterBridgeKit

final class WaterBridgeAlertTests: XCTestCase {
    @MainActor
    func testPayloadMessageIsPreservedForAllEnvelopeKeys() {
        let text = "안녕하세요\n메시지 & 100% <b>본문</b>"
        for key in ["data", "payload", "params"] {
            var displayed: String?
            let router = WaterBridgeRouter(configuration: .init(), onAlertRequested: { displayed = $0; return true })
            let response = router.response(for: message(["api": "water://alert", key: ["message": text]]))
            XCTAssertEqual(code(response), "0000")
            XCTAssertEqual(displayed, text)
        }
    }

    @MainActor
    func testQueryMessageDecodesOnce() throws {
        let text = "완료 & 다음 단계 + 100% %2F # 확인"
        var uri = URLComponents(string: "water://alert")!
        uri.queryItems = [URLQueryItem(name: "message", value: text)]
        var displayed: String?
        let router = WaterBridgeRouter(configuration: .init(), onAlertRequested: { displayed = $0; return true })
        XCTAssertEqual(code(router.response(for: message(try XCTUnwrap(uri.string)))), "0000")
        XCTAssertEqual(displayed, text)
    }

    @MainActor
    func testMissingBlankNonStringAndAmbiguousMessagesAreRejected() {
        var presentations = 0
        let router = WaterBridgeRouter(configuration: .init(), onAlertRequested: { _ in presentations += 1; return true })
        let bodies: [Any] = [
            "water://alert", "water://alert?message=", "water://alert?message=a&message=b",
            ["api": "water://alert", "data": ["message": " \n "]],
            ["api": "water://alert", "data": ["message": 123]],
            ["api": "water://alert?message=a", "data": ["message": "b"]]
        ]
        for body in bodies {
            XCTAssertEqual(code(router.response(for: message(body))), "9999")
        }
        XCTAssertEqual(presentations, 0)
    }

    @MainActor
    func testUnavailablePresenterReturnsFailure() {
        let router = WaterBridgeRouter(configuration: .init(), onAlertRequested: { _ in false })
        XCTAssertEqual(code(router.response(for: message("water://alert?message=test"))), "9999")
    }

    @MainActor
    func testCustomOverrideSuppressesDefaultAlert() {
        let router = WaterBridgeRouter(configuration: .init(additionalRoutes: [
            WaterBridgeRoute(api: "water://alert", version: 2) { _ in WaterBridgeResponse.success(data: [:]).value }
        ]), onAlertRequested: { _ in XCTFail("Custom route must take precedence"); return false })
        XCTAssertEqual(code(router.response(for: message("water://alert?message=test"))), "0000")
    }

    @MainActor
    func testRouteAPIListIncludesAlert() throws {
        let router = WaterBridgeRouter(configuration: .init())
        let response = try XCTUnwrap(router.response(for: message("water://routeApiList")) as? [String: Any])
        let routes = try XCTUnwrap(response["data"] as? [[String: Any]])
        XCTAssertEqual(routes.first(where: { $0["api"] as? String == "water://alert" })?["version"] as? Int, 1)
    }

    @MainActor
    func testVisibleAlertIsNotReplacedAndDismissalAllowsNextMessage() {
        let presentation = WaterBridgeAlertPresentation()
        XCTAssertTrue(presentation.present("첫 번째"))
        XCTAssertFalse(presentation.present("두 번째"))
        XCTAssertEqual(presentation.notice?.message, "첫 번째")
        presentation.notice = nil
        XCTAssertTrue(presentation.present("두 번째"))
        XCTAssertEqual(presentation.notice?.message, "두 번째")
    }

    private func message(_ body: Any) -> WaterBridgeMessage {
        .init(channel: "Bridge", body: body, sourceURL: nil)
    }

    private func code(_ response: Any) -> String? {
        ((response as? [String: Any])?["status"] as? [String: String])?["code"]
    }
}
