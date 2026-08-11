import XCTest
@testable import WaterBridgeCore

final class WaterBridgeMessageTests: XCTestCase {
    private let envelope = #"water://{"api":"water://routeApiList","data":{},"callback":"bridge_callback_065b4266e5f24883813aa48e8d700bab"}"#

    func testParsesWaterEnvelope() {
        let message = makeMessage(body: envelope)

        XCTAssertEqual(message.api, "water://routeApiList")
        XCTAssertNotNil(message.data as? [String: Any])
        XCTAssertEqual(
            message.callback,
            "bridge_callback_065b4266e5f24883813aa48e8d700bab"
        )
    }

    func testParsesEnvelopeWrappedInAPIField() {
        let message = makeMessage(body: ["api": envelope])

        XCTAssertEqual(message.api, "water://routeApiList")
        XCTAssertNotNil(message.data as? [String: Any])
        XCTAssertEqual(
            message.callback,
            "bridge_callback_065b4266e5f24883813aa48e8d700bab"
        )
    }

    func testParsesPercentEncodedEnvelope() throws {
        let encodedEnvelope = try XCTUnwrap(
            envelope.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        )
        let message = makeMessage(body: encodedEnvelope)

        XCTAssertEqual(message.api, "water://routeApiList")
        XCTAssertNotNil(message.data as? [String: Any])
        XCTAssertEqual(
            message.callback,
            "bridge_callback_065b4266e5f24883813aa48e8d700bab"
        )
    }

    private func makeMessage(body: Any) -> WaterBridgeMessage {
        WaterBridgeMessage(
            channel: "Bridge",
            body: body,
            sourceURL: nil
        )
    }
}
