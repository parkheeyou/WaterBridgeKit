import Foundation

/// WebKit이 JavaScript 객체로 직렬화할 수 있는 공통 브릿지 응답입니다.
package struct WaterBridgeResponse {
    package let code: String
    package let message: String
    package let data: Any

    package var value: [String: Any] {
        [
            "status": [
                "code": code,
                "message": message
            ],
            "data": data
        ]
    }

    package static func success(data: Any) -> Self {
        Self(code: "0000", message: "정상", data: data)
    }

    package static func failure(message: String) -> Self {
        Self(code: "9999", message: message, data: NSNull())
    }
}
