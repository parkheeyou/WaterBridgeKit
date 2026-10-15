import Foundation
import WaterBridgeCore

enum WaterBridgeWebTarget: String {
    case safari, webView
}

struct WaterBridgeWebDestination {
    let target: WaterBridgeWebTarget
    let url: URL
}

@MainActor
enum WaterBridgeOpenURLHandler {
    static let safariAPI = "water://openSafari"
    static let webViewAPI = "water://openWebView"

    static func safari(_ message: WaterBridgeMessage, context: WaterBridgeRouteContext) -> Any {
        handle(message, target: .safari, open: { _ in false })
    }

    static func webView(_ message: WaterBridgeMessage, context: WaterBridgeRouteContext) -> Any {
        handle(message, target: .webView, open: { _ in false })
    }

    static func handle(
        _ message: WaterBridgeMessage,
        target: WaterBridgeWebTarget,
        open: @MainActor (WaterBridgeWebDestination) -> Bool
    ) -> Any {
        guard let url = destinationURL(message) else {
            return WaterBridgeResponse.failure(message: "유효한 HTTP 또는 HTTPS url 파라미터가 필요합니다.").value
        }
        guard open(.init(target: target, url: url)) else {
            return WaterBridgeResponse.failure(message: "현재 화면에서 페이지 열기 요청을 처리할 수 없습니다.").value
        }
        // 외부 앱 실행은 비동기이므로 실제 열기 완료가 아닌 접수를 응답합니다.
        return WaterBridgeResponse.success(data: ["requested": true, "target": target.rawValue]).value
    }

    static func destinationURL(_ message: WaterBridgeMessage) -> URL? {
        let query = message.queryItems.filter { $0.name == "url" }
        guard query.count <= 1 else { return nil }
        let data = message.payload as? [String: Any]
        if let value = data?["url"], !(value is String) { return nil }
        let payloadURL = data?["url"] as? String
        if let payloadURL, let queryURL = query.first?.value, payloadURL != queryURL { return nil }
        guard let rawValue = payloadURL ?? query.first?.value else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }),
              value.range(of: "%(?![0-9a-fA-F]{2})", options: .regularExpression) == nil,
              let components = URLComponents(string: value),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else { return nil }
        return components.url
    }
}
