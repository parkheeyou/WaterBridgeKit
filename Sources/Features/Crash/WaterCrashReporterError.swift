import Foundation

public enum WaterCrashReporterError: LocalizedError {
    case reporterCreationFailed
    case reportFormattingFailed
    case applicationSupportDirectoryUnavailable

    public var errorDescription: String? {
        switch self {
        case .reporterCreationFailed:
            "크래시 수집기를 생성할 수 없습니다."
        case .reportFormattingFailed:
            "크래시 보고서를 로그 문자열로 변환할 수 없습니다."
        case .applicationSupportDirectoryUnavailable:
            "크래시 보고서를 저장할 Application Support 경로가 없습니다."
        }
    }
}
