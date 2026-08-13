import Foundation

/// WebKit이 JavaScript 객체로 직렬화할 수 있는 공통 브릿지 응답입니다.
public struct WaterBridgeResponse {
    public let code: String
    public let message: String
    public let data: Any

    public init(code: String, message: String, data: Any) {
        self.code = code
        self.message = message
        self.data = data
    }

    public var value: [String: Any] {
        [
            "status": [
                "code": code,
                "message": message
            ],
            "data": data
        ]
    }

    public static func success(data: Any) -> Self {
        Self(code: "0000", message: "정상", data: data)
    }

    public static func failure(message: String) -> Self {
        Self(code: "9999", message: message, data: NSNull())
    }
}
