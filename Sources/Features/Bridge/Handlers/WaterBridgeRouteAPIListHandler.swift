import WaterBridgeCore

/// 현재 등록된 네이티브 브릿지 API 목록을 반환합니다.
@MainActor
public final class WaterBridgeRouteAPIListHandler: WaterBridgeHandler {
    static let shared = WaterBridgeRouteAPIListHandler()
    
    let api = "routeApiList"
    
    func handle(
        _ message: WaterBridgeMessage,
        context: WaterBridgeRouteContext
    ) -> Any {
        WaterBridgeResponse.success(
            data: context.routes.map(\.value)
        ).value
    }
}
