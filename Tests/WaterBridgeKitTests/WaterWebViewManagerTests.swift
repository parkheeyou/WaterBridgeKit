#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit
import XCTest
@testable import WaterBridgeKit

final class WaterWebViewManagerTests: XCTestCase {
    @MainActor
    func testFindsHostedWebViewButIgnoresOrdinaryWebView() {
        let controller = UIViewController()
        let window = makeWindow(controller)
        controller.view.addSubview(WKWebView())
        XCTAssertNil(WaterWebViewManager.currentWebView(in: window))
        let webView = WaterHostedWebView()
        controller.view.addSubview(webView)
        XCTAssertTrue(WaterWebViewManager.currentWebView(in: window) === webView)
    }

    @MainActor
    func testHiddenAncestorAndDismantledViewsAreExcluded() {
        let controller = UIViewController()
        let window = makeWindow(controller)
        let container = UIView()
        let webView = WaterHostedWebView()
        controller.view.addSubview(container)
        container.addSubview(webView)
        container.isHidden = true
        XCTAssertNil(WaterWebViewManager.currentWebView(in: window))
        container.isHidden = false
        webView.isBridgeActive = false
        XCTAssertNil(WaterWebViewManager.currentWebView(in: window))
        webView.isBridgeActive = true
        XCTAssertTrue(WaterWebViewManager.currentWebView(in: window) === webView)
        window.isHidden = true
        XCTAssertNil(WaterWebViewManager.currentWebView(in: window))
    }

    @MainActor
    func testAmbiguousWebViewsAreNotSelected() {
        let controller = UIViewController()
        let window = makeWindow(controller)
        controller.view.addSubview(WaterHostedWebView())
        controller.view.addSubview(WaterHostedWebView())
        XCTAssertNil(WaterWebViewManager.currentWebView(in: window))
    }

    @MainActor
    func testUsesSelectedNavigationPage() {
        let first = UIViewController()
        let second = UIViewController()
        let navigation = UINavigationController()
        navigation.setViewControllers([first, second], animated: false)
        let window = makeWindow(navigation)
        let webView = WaterHostedWebView()
        second.view.addSubview(webView)
        XCTAssertTrue(WaterWebViewManager.currentWebView(in: window) === webView)
        navigation.popViewController(animated: false)
        XCTAssertNil(WaterWebViewManager.currentWebView(in: window))
    }

    @MainActor
    private func makeWindow(_ controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        window.rootViewController = controller
        window.isHidden = false
        window.layoutIfNeeded()
        return window
    }
}
#endif
