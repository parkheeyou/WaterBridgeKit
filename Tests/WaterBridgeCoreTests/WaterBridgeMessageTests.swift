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

    func testJSONInsideDestinationQueryIsNotAnEnvelope() throws {
        let target = "https://example.com/?config={\"api\":\"water://exit\"}"
        var components = URLComponents(string: "water://openWebView")!
        components.queryItems = [URLQueryItem(name: "url", value: target)]
        for body in [components.string! as Any, ["api": components.string!] as Any] {
            let message = makeMessage(body: body)
            XCTAssertEqual(message.api, "water://openWebView")
            XCTAssertEqual(message.queryItems.first?.value, target)
            XCTAssertNil(message.callback)
        }
    }

    func testEncodedJSONEnvelopeWithWaterPrefixStillParses() throws {
        let json = String(envelope.dropFirst("water://".count))
        let encoded = try XCTUnwrap(json.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        let command = "water://" + encoded
        for body in [command as Any, ["api": command] as Any] {
            let message = makeMessage(body: body)
            XCTAssertEqual(message.api, "water://routeApiList")
            XCTAssertNotNil(message.callback)
        }
    }

    private func makeMessage(body: Any) -> WaterBridgeMessage {
        WaterBridgeMessage(
            channel: "Bridge",
            body: body,
            sourceURL: nil
        )
    }
}
