#if canImport(UIKit) && canImport(WebKit)
import XCTest
import SwiftUI
import WebKit
@testable import WaterBridgeKit

final class WaterWebSystemLinkTests: XCTestCase {
    @MainActor
    func testRealWebLinksBypassBridgeIncludingNewWindow() async throws {
        for target in ["_self", "_blank"] {
            for scheme in ["tel", "sms"] {
                let url = URL(string: "\(scheme):01012345678")!
                let opened = expectation(description: "\(scheme) \(target)")
                var received: URL?
                let links = WaterWebSystemLinkHandler(open: {
                    received = $0
                    opened.fulfill()
                    return true
                }, onFailure: { _ in XCTFail("Unexpected failure") })
                let parent = WaterWebViewRepresentable(
                    url: URL(string: "https://example.com")!, bridgeConfiguration: .init(scheme: "test"),
                    lifecycle: .init(), isLoading: .constant(false), errorMessage: .constant(nil),
                    onBridgeMessage: { _ in XCTFail("System links must bypass bridge") },
                    onExitRequested: {}, onOpenRequested: { _ in XCTFail("Must use system link handler"); return false },
                    onAlertRequested: { _ in XCTFail("Unexpected alert"); return false }
                )
                let coordinator = WaterWebViewRepresentable.Coordinator(parent, systemLinks: links)
                let webView = WKWebView()
                coordinator.webView = webView
                let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".html")
                try Data("<html><body><a id='link' href='\(url.absoluteString)' target='\(target)'>Open</a></body></html>".utf8).write(to: file)
                defer {
                    links.cancel()
                    webView.navigationDelegate = nil
                    webView.uiDelegate = nil
                    try? FileManager.default.removeItem(at: file)
                }
                let navigation = SessionWebNavigation()
                try await navigation.load(file, in: webView)
                webView.navigationDelegate = coordinator
                webView.uiDelegate = coordinator
                _ = try await webView.evaluateJavaScript("document.getElementById('link').click()")
                await fulfillment(of: [opened], timeout: 5)
                XCTAssertEqual(received, url)
                XCTAssertEqual(webView.url, file)
            }
        }
    }

    @MainActor
    func testPhoneAndSMSPreserveURLAndIgnoreOtherSchemes() async throws {
        for text in ["tel:+82-10-1234-5678", "sms:01012345678", "TEL:0212345678", "sms:"] {
            var opened: URL?
            let handler = WaterWebSystemLinkHandler(open: { opened = $0; return true }, onFailure: { _ in XCTFail("Unexpected failure") })
            let url = try XCTUnwrap(URL(string: text))
            XCTAssertFalse(handler.handle(URL(string: "https://example.com")!, fromMainFrame: true))
            XCTAssertFalse(handler.handle(URL(string: "water://exit")!, fromMainFrame: true))
            XCTAssertFalse(handler.handle(URL(string: "mailto:hello@example.com")!, fromMainFrame: true))
            XCTAssertTrue(handler.handle(url, fromMainFrame: true))
            for _ in 0..<100 { if opened != nil { break }; await Task.yield() }
            XCTAssertEqual(opened, url)
        }
    }

    @MainActor
    func testIframeDoesNotLaunchAndDuplicateWhileOpeningIsIgnored() async throws {
        var calls = 0
        var resume: CheckedContinuation<Bool, Never>?
        let handler = WaterWebSystemLinkHandler(open: { _ in
            calls += 1
            return await withCheckedContinuation { resume = $0 }
        }, onFailure: { _ in XCTFail("Unexpected failure") })
        let url = try XCTUnwrap(URL(string: "tel:0212345678"))
        XCTAssertTrue(handler.handle(url, fromMainFrame: false))
        await Task.yield()
        XCTAssertEqual(calls, 0)
        XCTAssertTrue(handler.handle(url, fromMainFrame: true))
        for _ in 0..<100 { if resume != nil { break }; await Task.yield() }
        XCTAssertNotNil(resume)
        XCTAssertTrue(handler.handle(url, fromMainFrame: true))
        XCTAssertEqual(calls, 1)
        resume?.resume(returning: true)
    }

    @MainActor
    func testOpenFailureShowsUsefulMessageAndCancelledViewDoesNotAlert() async throws {
        for scheme in ["tel", "sms"] {
            var message: String?
            let handler = WaterWebSystemLinkHandler(open: { _ in false }, onFailure: { message = $0 })
            XCTAssertTrue(handler.handle(URL(string: "\(scheme):0212345678")!, fromMainFrame: true))
            for _ in 0..<100 { if message != nil { break }; await Task.yield() }
            XCTAssertTrue(try XCTUnwrap(message).contains(scheme == "tel" ? "전화" : "문자"))
        }
        var resume: CheckedContinuation<Bool, Never>?
        var failure = false
        let handler = WaterWebSystemLinkHandler(open: { _ in
            await withCheckedContinuation { resume = $0 }
        }, onFailure: { _ in failure = true })
        handler.handle(URL(string: "sms:0212345678")!, fromMainFrame: true)
        for _ in 0..<100 { if resume != nil { break }; await Task.yield() }
        XCTAssertNotNil(resume)
        handler.cancel()
        resume?.resume(returning: false)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(failure)
    }
}
#endif
