import WaterBridgeCore

/// WaterBridgeKit에서 지원하는 브릿지 API를 한 곳에서 관리합니다.
@MainActor
enum WaterBridgeRouteRegistry {
    static let routes = WaterBridgeAPI.all.map { definition in
        WaterBridgeRoute(
            api: definition.api,
            version: definition.version,
            handler: definition.handler
        )
    }

    static var descriptors: [[String: Any]] {
        routes.map(\.descriptor)
    }

    static func route(for api: String) -> WaterBridgeRoute? {
        routes.first { $0.api == api }
    }
}
