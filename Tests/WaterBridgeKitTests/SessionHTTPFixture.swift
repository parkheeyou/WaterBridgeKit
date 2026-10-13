#if canImport(WebKit)
import Foundation
import Network
import WebKit

/// 외부 서버 없이 실제 URLSession/WebKit의 Set-Cookie 처리를 검증하는 루프백 HTTP 서버입니다.
final class SessionHTTPFixture: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "WaterBridgeKit.SessionHTTPFixture")

    init() throws { listener = try NWListener(using: .tcp, on: .any) }

    func start() async throws -> URL {
        let queue = queue
        listener.newConnectionHandler = { connection in
            connection.start(queue: queue)
            Self.receive(connection, buffer: Data())
        }
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.listener.stateUpdateHandler = nil
                    guard let port = self.listener.port,
                          let url = URL(string: "http://127.0.0.1:\(port.rawValue)") else {
                        continuation.resume(throwing: URLError(.badURL))
                        return
                    }
                    continuation.resume(returning: url)
                case let .failed(error):
                    self.listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    func stop() { listener.cancel() }

    private static func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, complete, error in
            var buffer = buffer
            buffer.append(data ?? Data())
            guard buffer.range(of: Data("\r\n\r\n".utf8)) != nil else {
                if complete || error != nil { connection.cancel() }
                else { receive(connection, buffer: buffer) }
                return
            }
            let request = String(decoding: buffer, as: UTF8.self)
            let path = request.components(separatedBy: "\r\n").first?.components(separatedBy: " ").dropFirst().first ?? "/"
            let cookieHeader = request.components(separatedBy: "\r\n")
                .first(where: { $0.lowercased().hasPrefix("cookie:") })?
                .dropFirst(7).trimmingCharacters(in: .whitespaces) ?? "no-session"
            var headers = ""
            let body: String
            switch path {
            case "/web-login":
                headers = "Set-Cookie: session=web; Path=/; HttpOnly\r\n"
                body = "web-login"
            case "/native-login":
                headers = "Set-Cookie: session=native; Path=/; HttpOnly\r\n"
                body = "native-login"
            case "/logout":
                headers = "Set-Cookie: session=; Max-Age=0; Path=/; HttpOnly\r\n"
                body = "logged-out"
            default:
                body = cookieHeader
            }
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\(headers)\r\n\(body)"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}

@MainActor
final class SessionWebNavigation: NSObject, @preconcurrency WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func load(_ url: URL, in webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            webView.navigationDelegate = self
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(nil) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error) }

    private func finish(_ error: Error?) {
        let continuation = continuation
        self.continuation = nil
        if let error { continuation?.resume(throwing: error) }
        else { continuation?.resume() }
    }
}
#endif
