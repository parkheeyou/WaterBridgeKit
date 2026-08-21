import Foundation
import WaterBridgeCore

/// endpoint 목록을 `URLRequest`로 변환하고 `URLSession` 기반 transport로 전송합니다.
public final class WaterNetworkClient<API: WaterAPIEndpoint>: @unchecked Sendable {
    private let configuration: WaterNetworkConfiguration
    private let transport: any WaterNetworkTransport

    public init(
        configuration: WaterNetworkConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.transport = WaterURLSessionTransport(session: session)
    }

    /// 테스트 또는 별도 전송 구현이 필요할 때 transport를 주입합니다.
    public init(
        configuration: WaterNetworkConfiguration,
        transport: any WaterNetworkTransport
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    /// 성공 응답만 별도 모델로 디코딩하고 실패는 `WaterNetworkError`로 반환합니다.
    public func request<Response>(
        _ endpoint: API,
        request requestData: WaterAPIRequest = .plain,
        response responseType: Response.Type = Response.self
    ) async -> Result<Response, WaterNetworkError>
    where Response: Decodable & Sendable {
        let result: WaterNetworkResult<Response, WaterEmptyResponse> = await request(
            endpoint,
            request: requestData,
            response: responseType,
            errorResponse: WaterEmptyResponse.self
        )

        switch result {
        case let .success(response, _):
            return .success(response)
        case let .failure(failure):
            return .failure(failure.error)
        }
    }

    /// 성공 모델과 서버의 실패 모델을 각각 디코딩합니다.
    public func request<Response, Failure>(
        _ endpoint: API,
        request requestData: WaterAPIRequest = .plain,
        response responseType: Response.Type,
        errorResponse failureType: Failure.Type
    ) async -> WaterNetworkResult<Response, Failure>
    where Response: Decodable & Sendable, Failure: Decodable & Sendable {
        let startedAt = Date()
        let urlRequest: URLRequest

        do {
            urlRequest = try WaterURLRequestBuilder.makeRequest(
                endpoint: endpoint,
                requestData: requestData,
                configuration: configuration
            )
        } catch let error as WaterNetworkError {
            logFailure(endpoint: endpoint, error: error)
            return failure(error)
        } catch {
            let networkError = WaterNetworkError.requestEncoding(
                message: error.localizedDescription
            )
            logFailure(endpoint: endpoint, error: networkError)
            return failure(networkError)
        }

        logRequest(endpoint: endpoint, request: urlRequest)

        do {
            let (data, urlResponse) = try await transport.data(for: urlRequest)
            guard let httpResponse = urlResponse as? HTTPURLResponse else {
                logFailure(endpoint: endpoint, error: .invalidResponse)
                return failure(.invalidResponse)
            }

            let response = Self.makeResponse(
                data: data,
                httpResponse: httpResponse
            )
            logResponse(
                endpoint: endpoint,
                response: response,
                elapsedTime: Date().timeIntervalSince(startedAt)
            )

            guard configuration.validStatusCodes.contains(response.statusCode) else {
                let body = try? Self.decode(
                    failureType,
                    from: data,
                    decoderFactory: configuration.decoderFactory
                )
                return .failure(
                    WaterNetworkFailure(
                        error: .unacceptableStatusCode(
                            statusCode: response.statusCode,
                            data: data
                        ),
                        body: body,
                        response: response
                    )
                )
            }

            do {
                let value = try Self.decode(
                    responseType,
                    from: data,
                    decoderFactory: configuration.decoderFactory
                )
                return .success(value, response: response)
            } catch {
                let decodingError = WaterNetworkError.decoding(
                    statusCode: response.statusCode,
                    message: error.localizedDescription,
                    data: data
                )
                logFailure(endpoint: endpoint, error: decodingError)
                return .failure(
                    WaterNetworkFailure(
                        error: decodingError,
                        body: nil,
                        response: response
                    )
                )
            }
        } catch is CancellationError {
            logFailure(endpoint: endpoint, error: .cancelled)
            return failure(.cancelled)
        } catch let error as URLError where error.code == .cancelled {
            logFailure(endpoint: endpoint, error: .cancelled)
            return failure(.cancelled)
        } catch {
            let transportError = WaterNetworkError.transport(
                message: error.localizedDescription
            )
            logFailure(endpoint: endpoint, error: transportError)
            return failure(transportError)
        }
    }

    /// completion 방식으로 성공 응답만 디코딩합니다. 반환된 Task로 취소할 수 있습니다.
    @discardableResult
    public func request<Response>(
        _ endpoint: API,
        request requestData: WaterAPIRequest = .plain,
        response responseType: Response.Type = Response.self,
        completion: @escaping @MainActor @Sendable (
            Result<Response, WaterNetworkError>
        ) -> Void
    ) -> Task<Void, Never>
    where Response: Decodable & Sendable {
        Task {
            let result = await request(
                endpoint,
                request: requestData,
                response: responseType
            )
            await completion(result)
        }
    }

    /// completion 방식으로 성공 모델과 서버 실패 모델을 각각 디코딩합니다.
    @discardableResult
    public func request<Response, Failure>(
        _ endpoint: API,
        request requestData: WaterAPIRequest = .plain,
        response responseType: Response.Type,
        errorResponse failureType: Failure.Type,
        completion: @escaping @MainActor @Sendable (
            WaterNetworkResult<Response, Failure>
        ) -> Void
    ) -> Task<Void, Never>
    where Response: Decodable & Sendable, Failure: Decodable & Sendable {
        Task {
            let result = await request(
                endpoint,
                request: requestData,
                response: responseType,
                errorResponse: failureType
            )
            await completion(result)
        }
    }

    private func failure<Response, Failure>(
        _ error: WaterNetworkError
    ) -> WaterNetworkResult<Response, Failure>
    where Response: Sendable, Failure: Sendable {
        .failure(
            WaterNetworkFailure(
                error: error,
                body: nil,
                response: nil
            )
        )
    }

    private func logRequest(endpoint: API, request: URLRequest) {
        guard configuration.isLoggingEnabled else { return }

        WaterDebugLogger.api(
            "[REQUEST] \(endpoint.method.rawValue) \(endpoint.path)"
        )
        if configuration.isBodyLoggingEnabled,
           let body = request.httpBody,
           let bodyText = String(data: body, encoding: .utf8) {
            WaterDebugLogger.api("[REQUEST BODY] \(bodyText)")
        }
    }

    private func logResponse(
        endpoint: API,
        response: WaterNetworkResponse,
        elapsedTime: TimeInterval
    ) {
        guard configuration.isLoggingEnabled else { return }

        WaterDebugLogger.api(
            "[RESPONSE] \(endpoint.method.rawValue) \(endpoint.path) status=\(response.statusCode) bytes=\(response.data.count) elapsed=\(String(format: "%.3f", elapsedTime))s",
            level: configuration.validStatusCodes.contains(response.statusCode)
                ? .info
                : .warning
        )
        if configuration.isBodyLoggingEnabled,
           let bodyText = String(data: response.data, encoding: .utf8) {
            WaterDebugLogger.api("[RESPONSE BODY] \(bodyText)")
        }
    }

    private func logFailure(endpoint: API, error: WaterNetworkError) {
        guard configuration.isLoggingEnabled else { return }
        WaterDebugLogger.api(
            "[FAILED] \(endpoint.method.rawValue) \(endpoint.path) message=\(error.localizedDescription)",
            level: .error
        )
    }

    private static func decode<Value>(
        _ type: Value.Type,
        from data: Data,
        decoderFactory: WaterNetworkConfiguration.DecoderFactory
    ) throws -> Value where Value: Decodable {
        if type == Data.self, let value = data as? Value {
            return value
        }
        if type == WaterEmptyResponse.self,
           let value = WaterEmptyResponse() as? Value {
            return value
        }
        return try decoderFactory().decode(type, from: data)
    }

    private static func makeResponse(
        data: Data,
        httpResponse: HTTPURLResponse
    ) -> WaterNetworkResponse {
        let headers = httpResponse.allHeaderFields.reduce(
            into: [String: String]()
        ) { result, field in
            result[String(describing: field.key)] = String(describing: field.value)
        }

        return WaterNetworkResponse(
            statusCode: httpResponse.statusCode,
            data: data,
            headers: headers,
            url: httpResponse.url
        )
    }
}
