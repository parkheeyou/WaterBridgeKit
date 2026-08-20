import Foundation
import OSLog

/// 앱 고유 이벤트와 API 통신을 앱 내 디버그 콘솔에 기록합니다.
public enum WaterDebugLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "WaterBridgeKit",
        category: "WaterDebug"
    )

    public static func event(
        _ message: String,
        level: WaterDebugLogLevel = .info
    ) {
        log(message, category: .event, level: level)
    }

    public static func api(
        _ message: String,
        level: WaterDebugLogLevel = .info
    ) {
        log(message, category: .api, level: level)
    }

    public static func log(
        _ message: String,
        category: WaterDebugLogCategory = .custom,
        level: WaterDebugLogLevel = .info
    ) {
#if DEBUG
        logger.log(level: osLogType(for: level), "\(message, privacy: .public)")
        capture(message, category: category, level: level)
#endif
    }

    package static func capture(
        _ message: String,
        category: WaterDebugLogCategory,
        level: WaterDebugLogLevel = .info
    ) {
        WaterDebugLogCenter.shared.record(
            message,
            category: category,
            level: level
        )
    }

    private static func osLogType(for level: WaterDebugLogLevel) -> OSLogType {
        switch level {
        case .debug:
            .debug
        case .info:
            .info
        case .warning:
            .default
        case .error:
            .error
        }
    }
}
