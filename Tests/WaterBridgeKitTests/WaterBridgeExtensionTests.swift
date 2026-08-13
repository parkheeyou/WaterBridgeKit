import XCTest
@testable import WaterBridgeKit

final class WaterBridgeExtensionTests: XCTestCase {
    @MainActor
    func testCustomChannelAndAdditionalRoute() throws {
        let configuration = WaterBridgeConfiguration(
            channel: "AppBridge",
            additionalRoutes: [
                WaterBridgeRoute(
                    api: "water://appInfo",
                    version: 1
                ) { message in
                    WaterBridgeResponse.success(
                        data: message.data ?? [:]
                    ).value
                }
            ]
        )
        let router = WaterBridgeRouter(configuration: configuration)
        let response = try XCTUnwrap(
            router.response(
                for: message(
                    api: "water://appInfo",
                    data: ["name": "BCU"],
                    channel: configuration.channel
                )
            ) as? [String: Any]
        )
        let data = try XCTUnwrap(response["data"] as? [String: String])

        XCTAssertEqual(configuration.channel, "AppBridge")
        XCTAssertEqual(data["name"], "BCU")
    }

    @MainActor
    func testRouteAPIListIncludesAdditionalRoute() throws {
        let configuration = WaterBridgeConfiguration(
            additionalRoutes: [
                WaterBridgeRoute(
                    api: "water://appInfo",
                    version: 3
                ) { _ in
                    WaterBridgeResponse.success(data: [:]).value
                }
            ]
        )
        let router = WaterBridgeRouter(configuration: configuration)
        let response = try XCTUnwrap(
            router.response(
                for: message(
                    api: "water://routeApiList",
                    channel: configuration.channel
                )
            ) as? [String: Any]
        )
        let routes = try XCTUnwrap(
            response["data"] as? [[String: Any]]
        )
        let appRoute = routes.first {
            $0["api"] as? String == "water://appInfo"
        }

        XCTAssertEqual(appRoute?["version"] as? Int, 3)
    }

    @MainActor
    func testAdditionalRouteOverridesDefaultRoute() throws {
        let configuration = WaterBridgeConfiguration(
            additionalRoutes: [
                WaterBridgeRoute(
                    api: "water://nativeInfo",
                    version: 99
                ) { _ in
                    WaterBridgeResponse.success(
                        data: ["source": "app"]
                    ).value
                }
            ]
        )
        let router = WaterBridgeRouter(configuration: configuration)
        let response = try XCTUnwrap(
            router.response(
                for: message(
                    api: "water://nativeInfo",
                    channel: configuration.channel
                )
            ) as? [String: Any]
        )
        let data = try XCTUnwrap(response["data"] as? [String: String])

        XCTAssertEqual(data["source"], "app")
    }

    private func message(
        api: String,
        data: Any = [:],
        channel: String
    ) -> WaterBridgeMessage {
        WaterBridgeMessage(
            channel: channel,
            body: [
                "api": api,
                "data": data
            ],
            sourceURL: nil
        )
    }
}
