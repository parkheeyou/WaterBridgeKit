import WaterBridgeCore

/// 현재 등록된 네이티브 브릿지 API 목록을 반환합니다.
@MainActor
enum WaterBridgeRouteAPIListHandler {
    static func handle(_ message: WaterBridgeMessage) -> Any {
        WaterBridgeResponse.success(
            data: WaterBridgeRouteRegistry.descriptors
        ).value
    }
}
