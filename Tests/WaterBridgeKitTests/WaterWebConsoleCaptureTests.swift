#if DEBUG && canImport(UIKit) && canImport(WebKit)
import WebKit
import XCTest
@testable import WaterBridgeKit

final class WaterWebConsoleCaptureTests: XCTestCase {
    @MainActor
    func testEarlyLogsLevelsSerializationAndOriginalConsole() async throws {
        let received = expectation(description: "console messages")
        received.expectedFulfillmentCount = 6
        var logs: [(String, WaterDebugLogLevel)] = []
        let capture = WaterWebConsoleCapture { text, level in
            logs.append((text, level))
            received.fulfill()
        }
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: "window.originalCalls = 0; const originalLog = console.log; console.log = function(...args) { window.originalCalls++; return originalLog.apply(console, args); };", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        capture.install(on: config.userContentController)
        defer { capture.remove(from: config.userContentController) }
        let web = WKWebView(frame: .zero, configuration: config)
        let navigation = SessionWebNavigation()
        let file = try html("<script>console.log('early-page-log')</script>")
        defer { try? FileManager.default.removeItem(at: file) }
        try await navigation.load(file, in: web)
        _ = try await web.evaluateJavaScript("""
        const cycle = {value: 7}; cycle.self = cycle;
        const getter = Object.defineProperty({}, 'bad', {enumerable: true, get() { throw new Error('getter must not run'); }});
        console.log('values', cycle, 42n, undefined, getter, document.body);
        console.warn('warning-test');
        console.error(new Error('error-test'));
        console.debug('debug-test');
        console.info('info-test');
        """)
        await fulfillment(of: [received], timeout: 10)
        XCTAssertTrue(logs.contains { $0.0.contains("early-page-log") })
        XCTAssertTrue(logs.contains { $0.0.contains("[Circular]") && $0.0.contains("[Getter]") && $0.0.contains("42") })
        XCTAssertTrue(logs.contains { $0.0.contains("warning-test") && $0.1 == .warning })
        XCTAssertTrue(logs.contains { $0.0.contains("error-test") && $0.1 == .error })
        XCTAssertTrue(logs.contains { $0.0.contains("debug-test") && $0.1 == .debug })
        let calls = try await web.evaluateJavaScript("window.originalCalls")
        XCTAssertEqual(calls as? Int, 2)
    }

    @MainActor
    func testUncaughtErrorsRejectionsAndIframes() async throws {
        let received = expectation(description: "errors and iframe")
        received.expectedFulfillmentCount = 3
        var logs: [(String, WaterDebugLogLevel)] = []
        let capture = WaterWebConsoleCapture { text, level in
            logs.append((text, level)); received.fulfill()
        }
        let config = WKWebViewConfiguration()
        capture.install(on: config.userContentController)
        defer { capture.remove(from: config.userContentController) }
        let web = WKWebView(frame: .zero, configuration: config)
        let navigation = SessionWebNavigation()
        let file = try html("""
        <body><script>
        function emitErrors() {
            setTimeout(() => { throw new Error('uncaught-test'); }, 0);
            Promise.reject(new Error('rejection-test'));
            const frame = document.createElement('iframe');
            frame.srcdoc = '<script>console.log("iframe-test")<\\/script>';
            document.body.appendChild(frame);
        }
        </script></body>
        """)
        defer { try? FileManager.default.removeItem(at: file) }
        try await navigation.load(file, in: web)
        _ = try await web.evaluateJavaScript("emitErrors()")
        await fulfillment(of: [received], timeout: 10)
        let exception = try XCTUnwrap(logs.first { $0.0.contains("[console.exception]") })
        XCTAssertEqual(exception.1, .error)
        // file URL의 opaque origin에서는 WebKit이 오류 상세를 Script error.로 가릴 수 있습니다.
        XCTAssertTrue(exception.0.contains("uncaught-test") || exception.0.contains("Script error."))
        XCTAssertTrue(logs.contains { $0.0.contains("[console.rejection]") && $0.0.contains("rejection-test") && $0.1 == .error })
        XCTAssertTrue(logs.contains { $0.0.contains("[iframe]") && $0.0.contains("iframe-test") })
    }

    private func html(_ text: String) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".html")
        try Data(text.utf8).write(to: file)
        return file
    }
}
#endif
