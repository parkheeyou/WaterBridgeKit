import Foundation

/// 앱 내 디버그 콘솔에서 구분하여 표시할 로그 카테고리입니다.
public enum WaterDebugLogCategory: String, CaseIterable, Sendable {
    case event = "EVENT"
    case api = "API"
    case bridge = "BRIDGE"
    case webView = "WEBVIEW"
    case crash = "CRASH"
    case custom = "CUSTOM"
}

/// 앱 내 디버그 콘솔에서 표시할 로그 심각도입니다.
public enum WaterDebugLogLevel: String, Sendable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

/// 디버그 콘솔에 저장되는 단일 로그입니다.
public struct WaterDebugLogEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let category: WaterDebugLogCategory
    public let level: WaterDebugLogLevel
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: WaterDebugLogCategory,
        level: WaterDebugLogLevel,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
    }
}

/// 현재 실행 중 발생한 로그를 메모리에 보관합니다.
///
/// 로그는 DEBUG 빌드에서만 저장되며 오래된 항목부터 자동으로 제거됩니다.
public final class WaterDebugLogCenter: @unchecked Sendable {
    public static let shared = WaterDebugLogCenter()

    private let maximumEntryCount: Int
    private let lock = NSLock()
    private var storedEntries: [WaterDebugLogEntry] = []

    public init(maximumEntryCount: Int = 1_000) {
        self.maximumEntryCount = max(1, maximumEntryCount)
    }

    public func record(
        _ message: String,
        category: WaterDebugLogCategory,
        level: WaterDebugLogLevel = .info,
        timestamp: Date = Date()
    ) {
#if DEBUG
        let entry = WaterDebugLogEntry(
            timestamp: timestamp,
            category: category,
            level: level,
            message: message
        )

        lock.lock()
        defer { lock.unlock() }

        storedEntries.append(entry)
        let overflow = storedEntries.count - maximumEntryCount
        if overflow > 0 {
            storedEntries.removeFirst(overflow)
        }
#endif
    }

    public func entries() -> [WaterDebugLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return storedEntries
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        storedEntries.removeAll(keepingCapacity: true)
    }

    public func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        return entries().map { entry in
            let timestamp = formatter.string(from: entry.timestamp)
            return "[\(timestamp)][\(entry.category.rawValue)][\(entry.level.rawValue)] \(entry.message)"
        }
        .joined(separator: "\n")
    }
}
