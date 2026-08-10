import Foundation

/// WaterBridge가 처리할 수 있는 단일 네이티브 API 정의입니다.
package struct WaterBridgeRoute {
    package typealias Handler = @MainActor (WaterBridgeMessage) -> Any

    package let api: String
    package let version: Int
    package let handler: Handler

    package init(
        api: String,
        version: Int,
        handler: @escaping Handler
    ) {
        self.api = api
        self.version = version
        self.handler = handler
    }

    package var descriptor: [String: Any] {
        [
            "api": api,
            "version": version
        ]
    }

    @MainActor
    package func handle(_ message: WaterBridgeMessage) -> Any {
        handler(message)
    }
}
