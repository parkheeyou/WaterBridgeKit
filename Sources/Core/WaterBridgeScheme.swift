import Foundation

/// 브릿지 스킴은 URL 스킴 문법을 따르며, 일반 웹/파일 탐색 스킴과 구분해야 합니다.
public enum WaterBridgeScheme {
    public static func normalized(_ value: String) -> String {
        let scheme = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let valid = scheme.range(of: "^[a-z][a-z0-9+.-]*$", options: .regularExpression) != nil
        precondition(valid && !["http", "https", "file", "javascript", "data", "about"].contains(scheme),
                     "브릿지에는 유효한 전용 URL 스킴을 지정해야 합니다.")
        return scheme
    }
}
