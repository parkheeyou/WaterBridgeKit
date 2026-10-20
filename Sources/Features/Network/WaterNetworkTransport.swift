import Foundation

/// 실제 요청 전송 계층입니다. 테스트에서는 별도 transport로 교체할 수 있습니다.
public protocol WaterNetworkTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse)
    /// 반환하는 임시 파일의 소유권은 호출자에게 이전됩니다.
    func download(for request: URLRequest) async throws -> (URL, URLResponse)
}

public extension WaterNetworkTransport {
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) {
        throw WaterNetworkError.unsupportedTransfer
    }
    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        throw WaterNetworkError.unsupportedTransfer
    }
}

/// `URLSession`을 사용하는 기본 전송 계층입니다.
public struct WaterURLSessionTransport: WaterNetworkTransport {
    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) {
        try await session.upload(for: request, fromFile: file)
    }

    public func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        try await session.download(for: request)
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}
