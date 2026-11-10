import WaterBridgeCore

/// 현재 등록된 네이티브 브릿지 API 목록을 반환합니다.
@MainActor
final class WaterBridgeRouteAPIListHandler: WaterBridgeHandler {
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
    
    func asyncHandle(
        _ message: WaterBridgeMessage,
        context: WaterBridgeRouteContext
    ) async -> Any {
        "비동기 응답일때 사용"
    }
}
