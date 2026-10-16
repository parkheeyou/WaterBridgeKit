import Foundation
import WaterBridgeCore

@MainActor
enum WaterBridgeAlertHandler {
    static let api = "water://alert"

    static func handle(_ message: WaterBridgeMessage, context: WaterBridgeRouteContext) -> Any {
        handle(message, present: { _ in false })
    }

    static func handle(_ message: WaterBridgeMessage, present: @MainActor (String) -> Bool) -> Any {
        let items = message.queryItems.filter { $0.name == "message" }
        let payload = message.payload as? [String: Any]
        guard items.count <= 1 else { return invalidMessage() }
        if let value = payload?["message"], !(value is String) { return invalidMessage() }
        let text = payload?["message"] as? String
        if let text, let queryText = items.first?.value, text != queryText { return invalidMessage() }
        guard let text = text ?? items.first?.value,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return invalidMessage() }
        guard present(text) else {
            return WaterBridgeResponse.failure(message: "이미 알림을 표시 중이거나 알림을 표시할 수 없는 화면입니다.").value
        }
        return WaterBridgeResponse.success(data: ["requested": true]).value
    }

    private static func invalidMessage() -> Any {
        WaterBridgeResponse.failure(message: "비어 있지 않은 문자열 message 파라미터가 필요합니다.").value
    }
}
