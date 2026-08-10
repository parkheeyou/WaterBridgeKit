import WaterBridgeCore

/// WaterBridgeKit에서 지원하는 브릿지 API를 한 곳에서 관리합니다.
@MainActor
enum WaterBridgeRouteRegistry {
    static let routes: [WaterBridgeRoute] = [
        WaterBridgeRoute(
            api: "water://routeApiList",
            version: 2,
            handler: WaterBridgeRouteAPIListHandler.handle
        ),
        WaterBridgeRoute(
            api: "water://nativeInfo",
            version: 2,
            handler: WaterBridgeNativeInfoHandler.handle
        )
    ]

    static var descriptors: [[String: Any]] {
        routes.map(\.descriptor)
    }

    static func route(for api: String) -> WaterBridgeRoute? {
        routes.first { $0.api == api }
    }
}
