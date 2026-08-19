import Foundation

/// WaterBridgeKit 크래시 보고서 저장 방식을 설정합니다.
public struct WaterCrashReporterConfiguration: Sendable {
    /// 사람이 읽을 수 있는 `.log` 파일을 보관할 디렉터리입니다.
    /// `nil`이면 Application Support의 WaterBridgeKit/CrashReports를 사용합니다.
    public let directoryURL: URL?

    /// 보관할 최대 크래시 보고서 수입니다.
    public let maximumReportCount: Int

    /// 디버거가 연결된 상태에서도 크래시 수집기를 활성화할지 여부입니다.
    /// 디버깅 세션과의 충돌을 피하기 위해 기본값은 `false`입니다.
    public let enableWhenDebuggerAttached: Bool

    public init(
        directoryURL: URL? = nil,
        maximumReportCount: Int = 10,
        enableWhenDebuggerAttached: Bool = false
    ) {
        self.directoryURL = directoryURL
        self.maximumReportCount = max(1, maximumReportCount)
        self.enableWhenDebuggerAttached = enableWhenDebuggerAttached
    }
}

/// 크래시 수집기 시작 결과입니다.
public struct WaterCrashReporterStartResult: Sendable {
    /// 현재 프로세스에서 크래시 수집기가 활성화됐는지 나타냅니다.
    public let isEnabled: Bool

    /// 이전 실행의 크래시를 이번 실행에서 `.log`로 변환한 경우 그 파일 URL입니다.
    public let recoveredReportURL: URL?

    public init(isEnabled: Bool, recoveredReportURL: URL?) {
        self.isEnabled = isEnabled
        self.recoveredReportURL = recoveredReportURL
    }
}
