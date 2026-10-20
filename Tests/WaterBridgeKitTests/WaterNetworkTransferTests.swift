import Foundation
import XCTest
#if canImport(WebKit)
import WebKit
#endif
@testable import WaterBridgeKit

final class WaterNetworkTransferTests: XCTestCase {
    func testMultipartPreservesBinaryAndEscapesNames() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let binary = Data([0, 255, 10, 13, 42])
        try binary.write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let body = try WaterMultipartBody.make(
            files: [.init(url: source, name: "a\"b", fileName: "sample.bin")],
            fields: [.init(name: "label", value: "한글")], boundary: "test"
        )
        defer { try? FileManager.default.removeItem(at: body) }
        let data = try Data(contentsOf: body)
        XCTAssertNotNil(data.range(of: binary))
        XCTAssertNotNil(data.range(of: Data("name=\"a\\\"b\"".utf8)))
        XCTAssertNotNil(data.range(of: Data("한글\r\n".utf8)))
        XCTAssertTrue(data.suffix(10).elementsEqual(Data("--test--\r\n".utf8)))
    }

    func testRejectsHeaderInjectionAndNonFiles() throws {
        XCTAssertThrowsError(try WaterMultipartBody.validateFile(URL(string: "https://example.com/a")!))
        XCTAssertThrowsError(try WaterMultipartBody.make(files: [], fields: [.init(name: "a\r\nInjected: x", value: "v")], boundary: "test"))
    }

    func testDownloadMovesSuccessfulFileAndPreservesExistingDestination() async throws {
        let transport = TransferTransport(status: 200)
        let client = makeClient(transport)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        let result = await client.download(.file, to: destination)
        guard case let .success(response) = result else { return XCTFail("Expected success: \(result)") }
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(try Data(contentsOf: destination), Data("file content".utf8))
        let again = await client.download(.file, to: destination)
        guard case .failure(.file) = again else { return XCTFail("Expected existing-file error") }
        XCTAssertEqual(try Data(contentsOf: destination), Data("file content".utf8))
        let temp = await transport.lastTemporary
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(temp).path))
    }

    func testFailedDownloadDoesNotSaveAndCleansTemporaryFile() async throws {
        let transport = TransferTransport(status: 403)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let result = await makeClient(transport).download(.file, to: destination)
        guard case .failure(.unacceptableStatusCode(statusCode: 403, data: _)) = result else { return XCTFail("Expected HTTP error") }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        let temp = await transport.lastTemporary
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(temp).path))
    }

    func testUploadUsesTransferAndCommonHeadersAndDecodes() async throws {
        let transport = TransferTransport(status: 201)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1, 2, 3]).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        let result = await makeClient(transport).upload(.file, fileURL: source, response: Reply.self)
        guard case let .success(reply) = result else { return XCTFail("Expected upload success") }
        XCTAssertTrue(reply.ok)
        let captured = await transport.uploadRequest
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer test")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Content-Type"), "application/octet-stream")
        let uploaded = await transport.uploaded
        XCTAssertEqual(uploaded, Data([1, 2, 3]))
        _ = await makeClient(transport).upload(.file, files: [.init(url: source, name: "file")], response: Reply.self)
        let temporaryBody = await transport.uploadFile
        XCTAssertFalse(FileManager.default.fileExists(atPath: try XCTUnwrap(temporaryBody).path))
    }

    #if canImport(WebKit)
    @MainActor
    func testRealSessionTransfersSynchronizeCookies() async throws {
        let server = try SessionHTTPFixture()
        let base = try await server.start()
        defer { server.stop() }
        let store = WKWebsiteDataStore.nonPersistent()
        let sync = try WaterSessionSynchronizer(allowedDomains: ["127.0.0.1"], cookieNames: ["session"], websiteDataStore: store)
        let transport = sync.makeTransport()
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("upload".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }
        var uploadRequest = URLRequest(url: base.appendingPathComponent("native-login"))
        uploadRequest.httpMethod = "POST"
        let (_, uploadResponse) = try await transport.upload(for: uploadRequest, fromFile: source)
        XCTAssertEqual((uploadResponse as? HTTPURLResponse)?.statusCode, 200)
        let cookies = await store.httpCookieStore.allCookies()
        XCTAssertEqual(cookies.first(where: { $0.name == "session" })?.value, "native")
        let webCookie = try XCTUnwrap(HTTPCookie(properties: [.domain: "127.0.0.1", .path: "/", .name: "session", .value: "web", HTTPCookiePropertyKey("HttpOnly"): "TRUE"]))
        await store.httpCookieStore.setCookie(webCookie)
        let (file, _) = try await transport.download(for: URLRequest(url: base.appendingPathComponent("echo")))
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "session=web")
        await sync.clearSession()
        await sync.stopObserving()
    }
    #endif

    private func makeClient(_ transport: TransferTransport) -> WaterNetworkClient<TransferAPI> {
        WaterNetworkClient(configuration: .init(baseURL: URL(string: "https://example.com")!, isLoggingEnabled: false, headerProvider: { ["Authorization": "Bearer test"] }), transport: transport)
    }
}

private enum TransferAPI: WaterAPIEndpoint {
    case file
    var path: String { "/file" }
    var method: WaterHTTPMethod { .post }
}
private struct Reply: Decodable, Sendable { let ok: Bool }
private actor TransferTransport: WaterNetworkTransport {
    let status: Int
    var lastTemporary: URL?
    var uploadRequest: URLRequest?
    var uploaded: Data?
    var uploadFile: URL?
    init(status: Int) { self.status = status }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) { fatalError("Must use transfer") }
    func upload(for request: URLRequest, fromFile file: URL) async throws -> (Data, URLResponse) {
        uploadRequest = request
        uploadFile = file
        uploaded = try Data(contentsOf: file)
        return (Data(#"{"ok":true}"#.utf8), response(request))
    }
    func download(for request: URLRequest) async throws -> (URL, URLResponse) {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("file content".utf8).write(to: file)
        lastTemporary = file
        return (file, response(request))
    }
    private func response(_ request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }
}
