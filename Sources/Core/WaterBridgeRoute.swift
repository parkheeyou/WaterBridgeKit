import Foundation

/// WaterBridge가 처리할 수 있는 단일 네이티브 API 정의입니다.
struct WaterBridgeRoute {
    typealias Handler = @MainActor (WaterBridgeMessage) -> Any

    let api: String
    let version: Int
    let handler: Handler

    var descriptor: [String: Any] {
        [
            "api": api,
            "version": version
        ]
    }

    @MainActor
    func handle(_ message: WaterBridgeMessage) -> Any {
        handler(message)
    }
}
