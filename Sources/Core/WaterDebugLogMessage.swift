/// 큰 body/base64 문자열을 UI와 시스템 로그에서 안전하게 확인할 수 있는 요약으로 만듭니다.
package enum WaterDebugLogMessage {
    package static let defaultMaximumLength = 400

    /// 제한은 본문 글자 수이며 생략 안내 길이는 별도입니다. Unicode Character 경계를 유지합니다.
    package static func preview(
        _ message: String,
        maximumLength: Int = defaultMaximumLength
    ) -> String {
        let limit = max(1, maximumLength)
        let length = message.count
        
        guard length > limit else { return message }
        
        let tailCount = limit / 4
        let headCount = limit - tailCount
        
        return String(
            message.prefix(headCount))
            + "\n… [로그 생략: 전체 \(length)자 중 \(length - limit)자 생략] …\n"
            + String(message.suffix(tailCount)
        )
    }
}
