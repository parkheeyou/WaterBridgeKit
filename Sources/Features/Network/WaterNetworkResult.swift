/// 서버가 내려준 실패 모델과 원본 응답을 함께 제공합니다.
public struct WaterNetworkFailure<Failure>: Sendable where Failure: Sendable {
    public let error: WaterNetworkError
    public let body: Failure?
    public let response: WaterNetworkResponse?

    public init(
        error: WaterNetworkError,
        body: Failure?,
        response: WaterNetworkResponse?
    ) {
        self.error = error
        self.body = body
        self.response = response
    }
}

/// 성공 응답과 서버 실패 응답을 명확히 구분하는 결과입니다.
public enum WaterNetworkResult<Success, Failure>: Sendable
where Success: Sendable, Failure: Sendable {
    case success(Success, response: WaterNetworkResponse)
    case failure(WaterNetworkFailure<Failure>)
}
