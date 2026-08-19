import CrashReporter
import Darwin
import Foundation
import WaterBridgeCore

/// 앱 크래시를 수집하고 다음 실행에서 사람이 읽을 수 있는 로그 파일로 보존합니다.
@MainActor
public final class WaterCrashReporter {
    public static let shared = WaterCrashReporter()

    public private(set) var isEnabled = false
    public private(set) var lastRecoveredReportURL: URL?

    private var crashReporter: PLCrashReporter?
    private var configuration = WaterCrashReporterConfiguration()

    public init() {}

    /// 앱 시작 시 가능한 한 이른 시점에 호출합니다.
    ///
    /// 실제 크래시 순간에는 PLCrashReporter가 안전한 원본 보고서를 기록하고,
    /// 다음 실행의 이 메서드 호출에서 읽을 수 있는 `.log` 파일로 변환합니다.
    @discardableResult
    public func start(
        configuration: WaterCrashReporterConfiguration = .init()
    ) throws -> WaterCrashReporterStartResult {
        self.configuration = configuration

        if crashReporter != nil {
            return WaterCrashReporterStartResult(
                isEnabled: isEnabled,
                recoveredReportURL: lastRecoveredReportURL
            )
        }

        #if DEBUG
        let reporterConfiguration = PLCrashReporterConfig(
            signalHandlerType: .mach,
            symbolicationStrategy: .all
        )
        #else
        let reporterConfiguration = PLCrashReporterConfig(
            signalHandlerType: .mach,
            symbolicationStrategy: []
        )
        #endif
        guard let reporter = PLCrashReporter(
            configuration: reporterConfiguration
        ) else {
            throw WaterCrashReporterError.reporterCreationFailed
        }

        lastRecoveredReportURL = try recoverPendingReport(from: reporter)

        guard configuration.enableWhenDebuggerAttached || !isDebuggerAttached else {
            WaterBridgeLogger.crashReporterSkippedForDebugger()
            return WaterCrashReporterStartResult(
                isEnabled: false,
                recoveredReportURL: lastRecoveredReportURL
            )
        }

        try reporter.enableAndReturnError()
        crashReporter = reporter
        isEnabled = true
        WaterBridgeLogger.crashReporterEnabled()

        return WaterCrashReporterStartResult(
            isEnabled: true,
            recoveredReportURL: lastRecoveredReportURL
        )
    }

    /// 저장되어 있는 크래시 로그 URL을 최신순으로 반환합니다.
    public func reportURLs() throws -> [URL] {
        let directoryURL = try reportDirectoryURL()
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return []
        }

        return try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasSuffix(".crash.log") }
        .sorted { lhs, rhs in
            let lhsDate = try? lhs.resourceValues(
                forKeys: [.creationDateKey]
            ).creationDate
            let rhsDate = try? rhs.resourceValues(
                forKeys: [.creationDateKey]
            ).creationDate
            return (lhsDate ?? .distantPast) > (rhsDate ?? .distantPast)
        }
    }

    public func latestReportURL() throws -> URL? {
        try reportURLs().first
    }

    public func latestReportText() throws -> String? {
        guard let url = try latestReportURL() else { return nil }
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func removeAllReports() throws {
        for url in try reportURLs() {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func recoverPendingReport(
        from reporter: PLCrashReporter
    ) throws -> URL? {
        guard reporter.hasPendingCrashReport() else { return nil }

        let data = try reporter.loadPendingCrashReportDataAndReturnError()
        let report = try PLCrashReport(data: data)
        guard let text = PLCrashReportTextFormatter.stringValue(
            for: report,
            with: PLCrashReportTextFormatiOS
        ) else {
            throw WaterCrashReporterError.reportFormattingFailed
        }

        let directoryURL = try reportDirectoryURL()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let reportURL = directoryURL.appendingPathComponent(
            "water-crash-\(Self.fileTimestamp.string(from: Date()))-\(UUID().uuidString).crash.log"
        )
        try text.write(to: reportURL, atomically: true, encoding: .utf8)

        // 파일 저장에 성공한 뒤에만 PLCrashReporter의 원본을 정리합니다.
        reporter.purgePendingCrashReport()
        try pruneReportsIfNeeded()
        WaterBridgeLogger.crashReportRecovered(url: reportURL)
        return reportURL
    }

    private func pruneReportsIfNeeded() throws {
        let urls = try reportURLs()
        guard urls.count > configuration.maximumReportCount else { return }

        for url in urls.dropFirst(configuration.maximumReportCount) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func reportDirectoryURL() throws -> URL {
        if let directoryURL = configuration.directoryURL {
            return directoryURL
        }

        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw WaterCrashReporterError.applicationSupportDirectoryUnavailable
        }

        return applicationSupportURL
            .appendingPathComponent("WaterBridgeKit", isDirectory: true)
            .appendingPathComponent("CrashReports", isDirectory: true)
    }

    private var isDebuggerAttached: Bool {
        var processInfo = kinfo_proc()
        var processInfoSize = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let nameCount = u_int(name.count)

        let result = name.withUnsafeMutableBufferPointer { namePointer in
            sysctl(
                namePointer.baseAddress,
                nameCount,
                &processInfo,
                &processInfoSize,
                nil,
                0
            )
        }
        guard result == 0 else { return false }
        return (processInfo.kp_proc.p_flag & P_TRACED) != 0
    }

    private static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter
    }()
}
