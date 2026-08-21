import Foundation

/// 요청 생성부터 응답 디코딩까지 발생할 수 있는 공통 네트워크 오류입니다.
public enum WaterNetworkError: Error, Sendable, Equatable {
    case invalidURL(path: String)
    case requestEncoding(message: String)
    case invalidResponse
    case cancelled
    case transport(message: String)
    case unacceptableStatusCode(statusCode: Int, data: Data)
    case decoding(statusCode: Int, message: String, data: Data)
}

extension WaterNetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidURL(path):
            "유효하지 않은 API 주소입니다: \(path)"
        case let .requestEncoding(message):
            "요청 데이터 인코딩에 실패했습니다: \(message)"
        case .invalidResponse:
            "HTTP 응답을 확인할 수 없습니다."
        case .cancelled:
            "API 요청이 취소되었습니다."
        case let .transport(message):
            message
        case let .unacceptableStatusCode(statusCode, _):
            "허용되지 않은 HTTP 상태 코드입니다: \(statusCode)"
        case let .decoding(statusCode, message, _):
            "응답 디코딩에 실패했습니다. status=\(statusCode), message=\(message)"
        }
    }
}
