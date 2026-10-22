#if canImport(UIKit) && canImport(WebKit)
import SwiftUI
import WebKit
import XCTest
@testable import WaterBridgeKit

final class WaterBridgeWebSchemeTests: XCTestCase {
    @MainActor
    func testRealWebKitNameOnlyMessagesUseConfiguredScheme() async throws {
        for scheme in ["water", "test"] {
            var alertText: String?
            var receivedScheme: String?
            let configuration = WaterBridgeConfiguration(channel: "AppBridge", scheme: scheme, additionalRoutes: [
                WaterBridgeRoute(api: "appInfo", version: 1) { message in
                    WaterBridgeResponse.success(data: ["api": message.api ?? ""]).value
                }
            ])
            let parent = WaterWebViewRepresentable(
                url: URL(string: "https://example.com")!, bridgeConfiguration: configuration,
                lifecycle: .init(), isLoading: .constant(false), errorMessage: .constant(nil),
                onBridgeMessage: { receivedScheme = $0.scheme }, onExitRequested: {},
                onOpenRequested: { _ in true }, onAlertRequested: { alertText = $0; return true }
            )
            let coordinator = parent.makeCoordinator()
            let webConfiguration = WKWebViewConfiguration()
            webConfiguration.websiteDataStore = .nonPersistent()
            webConfiguration.userContentController.addScriptMessageHandler(coordinator, contentWorld: .page, name: configuration.channel)
            let webView = WKWebView(frame: .zero, configuration: webConfiguration)
            coordinator.webView = webView
            let navigation = SessionWebNavigation()
            let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".html")
            try Data("<html><body>Bridge test</body></html>".utf8).write(to: file)
            defer {
                try? FileManager.default.removeItem(at: file)
                webConfiguration.userContentController.removeScriptMessageHandler(forName: configuration.channel)
            }
            try await navigation.load(file, in: webView)
            let appResponse = try await webView.callAsyncJavaScript(
                "return await window.webkit.messageHandlers.AppBridge.postMessage({api: 'appInfo', data: {source: 'bridge-demo'}});",
                arguments: [:], in: nil, contentWorld: .page
            )
            let response = try XCTUnwrap(appResponse as? [String: Any])
            let data = try XCTUnwrap(response["data"] as? [String: String])
            XCTAssertEqual(data["api"], "\(scheme)://appInfo")
            XCTAssertEqual(receivedScheme, scheme)
            _ = try await webView.callAsyncJavaScript(
                "return await window.webkit.messageHandlers.AppBridge.postMessage({api: 'alert', data: {message: 'hello'}});",
                arguments: [:], in: nil, contentWorld: .page
            )
            XCTAssertEqual(alertText, "hello")
            let listResponse = try await webView.callAsyncJavaScript(
                "return await window.webkit.messageHandlers.AppBridge.postMessage({api: 'routeApiList'});",
                arguments: [:], in: nil, contentWorld: .page
            )
            let list = try XCTUnwrap((listResponse as? [String: Any])?["data"] as? [[String: Any]])
            XCTAssertTrue(list.contains { $0["api"] as? String == "\(scheme)://appInfo" })
        }
    }
}
#endif
