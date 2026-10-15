import WaterBridgeCore

@MainActor
enum WaterBridgeExitHandler {
    static let api = "water://exit"

    /// 이 응답은 확인 창 표시 요청의 접수를 뜻하며, 사용자의 종료 동의가 아닙니다.
    static func handle(_ message: WaterBridgeMessage, context: WaterBridgeRouteContext) -> Any {
        WaterBridgeResponse.success(data: ["confirmationRequired": true]).value
    }
}
