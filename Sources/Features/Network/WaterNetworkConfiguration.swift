import Foundation

/// 모든 API 요청에 공통으로 적용할 네트워크 설정입니다.
public struct WaterNetworkConfiguration: @unchecked Sendable {
    public typealias HeaderProvider = @Sendable () -> [String: String]
    public typealias EncoderFactory = @Sendable () -> JSONEncoder
    public typealias DecoderFactory = @Sendable () -> JSONDecoder

    public let baseURL: URL
    public let headers: [String: String]
    public let timeoutInterval: TimeInterval
    public let validStatusCodes: Range<Int>
    public let isLoggingEnabled: Bool
    public let isBodyLoggingEnabled: Bool
    package let headerProvider: HeaderProvider
    package let encoderFactory: EncoderFactory
    package let decoderFactory: DecoderFactory

    public init(
        baseURL: URL,
        headers: [String: String] = [
            "Accept": "application/json"
        ],
        timeoutInterval: TimeInterval = 30,
        validStatusCodes: Range<Int> = 200..<300,
        isLoggingEnabled: Bool = true,
        isBodyLoggingEnabled: Bool = false,
        headerProvider: @escaping HeaderProvider = { [:] },
        encoderFactory: @escaping EncoderFactory = { JSONEncoder() },
        decoderFactory: @escaping DecoderFactory = { JSONDecoder() }
    ) {
        self.baseURL = baseURL
        self.headers = headers
        self.timeoutInterval = max(1, timeoutInterval)
        self.validStatusCodes = validStatusCodes
        self.isLoggingEnabled = isLoggingEnabled
        self.isBodyLoggingEnabled = isBodyLoggingEnabled
        self.headerProvider = headerProvider
        self.encoderFactory = encoderFactory
        self.decoderFactory = decoderFactory
    }
}
