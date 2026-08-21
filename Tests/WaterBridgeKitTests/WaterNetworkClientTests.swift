import Foundation
import XCTest
@testable import WaterBridgeKit

final class WaterNetworkClientTests: XCTestCase {
    func testJSONRequestAndSuccessResponse() async throws {
        let transport = MockTransport(
            statusCode: 201,
            data: Data(#"{"id":7,"name":"Water"}"#.utf8)
        )
        let client = makeClient(transport: transport)

        let result = await client.request(
            .createUser,
            request: .json(CreateUserRequest(name: "Water")),
            response: UserResponse.self
        )

        switch result {
        case let .success(user):
            XCTAssertEqual(user, UserResponse(id: 7, name: "Water"))
        case let .failure(error):
            XCTFail("Expected success, received: \(error)")
        }

        let capturedRequest = await transport.receivedRequest()
        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/v1/users")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Common"), "common")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Endpoint"), "create-user")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        XCTAssertEqual(
            try JSONDecoder().decode(CreateUserRequest.self, from: body),
            CreateUserRequest(name: "Water")
        )
    }

    func testQueryEncodableRequest() async throws {
        let transport = MockTransport(
            statusCode: 200,
            data: Data(#"{"id":1,"name":"One"}"#.utf8)
        )
        let client = makeClient(transport: transport)

        _ = await client.request(
            .users,
            request: .queryEncodable(UserQuery(page: 2, keyword: "water bridge")),
            response: UserResponse.self
        )

        let capturedRequest = await transport.receivedRequest()
        let request = try XCTUnwrap(capturedRequest)
        let components = try XCTUnwrap(
            URLComponents(
                url: try XCTUnwrap(request.url),
                resolvingAgainstBaseURL: false
            )
        )
        let values = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value)
            }
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(values["page"]!, "2")
        XCTAssertEqual(values["keyword"]!, "water bridge")
    }

    func testDecodesCustomFailureResponse() async {
        let transport = MockTransport(
            statusCode: 422,
            data: Data(#"{"code":"INVALID_NAME","message":"이름 오류"}"#.utf8)
        )
        let client = makeClient(transport: transport)

        let result = await client.request(
            .createUser,
            request: .json(CreateUserRequest(name: "")),
            response: UserResponse.self,
            errorResponse: APIErrorResponse.self
        )

        switch result {
        case .success:
            XCTFail("Expected failure")
        case let .failure(failure):
            XCTAssertEqual(failure.response?.statusCode, 422)
            XCTAssertEqual(
                failure.body,
                APIErrorResponse(code: "INVALID_NAME", message: "이름 오류")
            )
            guard case let .unacceptableStatusCode(statusCode, _) = failure.error else {
                return XCTFail("Expected unacceptableStatusCode")
            }
            XCTAssertEqual(statusCode, 422)
        }
    }

    private func makeClient(
        transport: MockTransport
    ) -> WaterNetworkClient<TestAPI> {
        WaterNetworkClient(
            configuration: WaterNetworkConfiguration(
                baseURL: URL(string: "https://api.example.com/v1")!,
                headers: ["X-Common": "common"],
                isLoggingEnabled: false,
                headerProvider: {
                    ["Authorization": "Bearer token"]
                }
            ),
            transport: transport
        )
    }
}

private enum TestAPI: WaterAPIEndpoint {
    case users
    case createUser

    var path: String { "/users" }

    var method: WaterHTTPMethod {
        switch self {
        case .users: .get
        case .createUser: .post
        }
    }

    var headers: [String: String]? {
        switch self {
        case .users: nil
        case .createUser: ["X-Endpoint": "create-user"]
        }
    }
}

private struct CreateUserRequest: Codable, Sendable, Equatable {
    let name: String
}

private struct UserQuery: Encodable, Sendable {
    let page: Int
    let keyword: String
}

private struct UserResponse: Decodable, Sendable, Equatable {
    let id: Int
    let name: String
}

private struct APIErrorResponse: Decodable, Sendable, Equatable {
    let code: String
    let message: String
}

private actor MockTransport: WaterNetworkTransport {
    private let statusCode: Int
    private let responseData: Data
    private var request: URLRequest?

    init(statusCode: Int, data: Data) {
        self.statusCode = statusCode
        self.responseData = data
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }

    func receivedRequest() -> URLRequest? {
        request
    }
}
