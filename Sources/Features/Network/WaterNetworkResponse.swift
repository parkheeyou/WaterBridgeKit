import Foundation

/// 성공 또는 실패 결과와 함께 전달되는 원본 HTTP 응답 정보입니다.
public struct WaterNetworkResponse: Sendable, Equatable {
    public let statusCode: Int
    public let data: Data
    public let headers: [String: String]
    public let url: URL?

    public init(
        statusCode: Int,
        data: Data,
        headers: [String: String],
        url: URL?
    ) {
        self.statusCode = statusCode
        self.data = data
        self.headers = headers
        self.url = url
    }
}

/// 응답 본문이 없는 성공 API에 사용하는 타입입니다.
public struct WaterEmptyResponse: Decodable, Sendable, Equatable {
    public init() {}
}
