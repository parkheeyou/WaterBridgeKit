import Foundation

/// 실제 요청 전송 계층입니다. 테스트에서는 별도 transport로 교체할 수 있습니다.
public protocol WaterNetworkTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// `URLSession`을 사용하는 기본 전송 계층입니다.
public struct WaterURLSessionTransport: WaterNetworkTransport {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
