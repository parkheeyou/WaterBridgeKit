import WaterBridgeCore

/// 브릿지 메시지를 현재 WebView에 등록된 API 처리기로 전달합니다.
@MainActor
struct WaterBridgeRouter {
    private let registry: WaterBridgeRouteRegistry
    private let context: WaterBridgeRouteContext

    init(configuration: WaterBridgeConfiguration) {
        let registry = WaterBridgeRouteRegistry(
            additionalRoutes: configuration.additionalRoutes
        )
        self.registry = registry
        self.context = WaterBridgeRouteContext(
            channel: configuration.channel,
            routes: registry.descriptors
        )
    }

    func response(for message: WaterBridgeMessage) -> Any {
        guard let api = message.api else {
            return WaterBridgeResponse
                .failure(message: "브릿지 API가 없습니다.")
                .value
        }

        guard let route = registry.route(for: api) else {
            return WaterBridgeResponse
                .failure(message: "지원하지 않는 API입니다: \(api)")
                .value
        }

        return route.handle(message, context: context)
    }
}
