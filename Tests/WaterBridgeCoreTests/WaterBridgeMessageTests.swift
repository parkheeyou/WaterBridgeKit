import XCTest
@testable import WaterBridgeCore

final class WaterBridgeMessageTests: XCTestCase {
    func testCustomSchemeRawJSONAndEncodedEnvelopes() throws {
        let bodies: [Any] = [
            "MYAPP://alert?message=hello",
            ["api": "myapp://alert", "data": ["message": "hello"]],
            ["action": "alert", "data": ["message": "hello"]],
            #"myapp://{"api":"myapp://alert","data":{"message":"hello"},"callback":"done"}"#,
            #"myapp://%7B%22api%22%3A%22myapp%3A%2F%2Falert%22%7D"#,
            ["api": #"myapp://{"api":"myapp://alert","data":{"message":"hello"}}"#]
        ]
        for body in bodies {
            let message = WaterBridgeMessage(channel: "CustomChannel", body: body, sourceURL: nil, scheme: "myapp")
            XCTAssertEqual(message.api, "myapp://alert", "body=\(body)")
        }
    }

    func testCustomSchemePreservesDestinationAndDoesNotRewriteAnotherScheme() {
        let message = WaterBridgeMessage(channel: "Bridge", body: "myapp://openSafari?url=https%3A%2F%2Fexample.com%2F%3Fq%3D%257Bdata%257D", sourceURL: nil, scheme: "myapp")
        XCTAssertEqual(message.api, "myapp://openSafari")
        XCTAssertEqual(message.queryItems.first?.value, "https://example.com/?q=%7Bdata%7D")
        let other = WaterBridgeMessage(channel: "Bridge", body: "water://exit", sourceURL: nil, scheme: "myapp")
        XCTAssertEqual(other.api, "water://exit")
    }

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
