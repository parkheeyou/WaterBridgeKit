import Foundation

/// JavaScript에서 네이티브로 전달한 브릿지 메시지입니다.
public struct WaterBridgeMessage {
    /// 등록된 WebKit 메시지 핸들러 이름입니다. 기본값은 `waterBridge`입니다.
    public let channel: String

    /// JavaScript의 `postMessage`에 전달된 원본 값입니다.
    public let body: Any

    /// 메시지를 보낸 메인 문서의 URL입니다.
    public let sourceURL: URL?

    public init(channel: String, body: Any, sourceURL: URL?) {
        self.channel = channel
        self.body = body
        self.sourceURL = sourceURL
    }

    /// `{ action: "..." }` 형태로 전달했을 때의 액션 이름입니다.
    public var action: String? {
        (body as? [String: Any])?["action"] as? String
    }

    /// `{ payload: ... }` 형태로 전달했을 때의 payload입니다.
    public var payload: Any? {
        guard let dictionary = body as? [String: Any] else { return nil }
        return dictionary["payload"] ?? dictionary["params"]
    }

    /// `water://...` 형식으로 전달된 브릿지 API입니다.
    public var api: String? {
        func normalizedAPI(_ value: Any?) -> String? {
            guard let value = value as? String, !value.isEmpty else { return nil }
            return value.hasPrefix("water://") ? value : "water://\(value)"
        }

        if let api = normalizedAPI(body) { return api }
        guard let dictionary = body as? [String: Any] else { return nil }
        return normalizedAPI(dictionary["api"])
            ?? normalizedAPI(dictionary["method"])
            ?? normalizedAPI(dictionary["name"])
            ?? normalizedAPI(dictionary["action"])
    }
}

/// 메인 액터에서 JavaScript 브릿지 메시지를 처리하는 콜백입니다.
public typealias WaterBridgeMessageHandler = @MainActor (WaterBridgeMessage) -> Void
