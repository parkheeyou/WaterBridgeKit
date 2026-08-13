import WaterBridgeCore

/// 기본 Route와 앱에서 전달한 추가 Route를 합쳐 관리합니다.
@MainActor
struct WaterBridgeRouteRegistry {
    let routes: [WaterBridgeRoute]

    init(additionalRoutes: [WaterBridgeRoute] = []) {
        let defaultRoutes = WaterBridgeAPI.all.map { definition in
            WaterBridgeRoute(
                api: definition.api,
                version: definition.version,
                handler: definition.handler
            )
        }
        routes = Self.merging(
            defaultRoutes: defaultRoutes,
            additionalRoutes: additionalRoutes
        )
    }

    var descriptors: [WaterBridgeRouteDescriptor] {
        routes.map(\.descriptor)
    }

    func route(for api: String) -> WaterBridgeRoute? {
        routes.first { $0.api == api }
    }

    /// 앱 Route가 기본 Route와 같은 API를 사용하면 앱 구현을 우선합니다.
    private static func merging(
        defaultRoutes: [WaterBridgeRoute],
        additionalRoutes: [WaterBridgeRoute]
    ) -> [WaterBridgeRoute] {
        var routes = defaultRoutes

        for route in additionalRoutes {
            if let index = routes.firstIndex(where: { $0.api == route.api }) {
                routes[index] = route
            } else {
                routes.append(route)
            }
        }

        return routes
    }
}
