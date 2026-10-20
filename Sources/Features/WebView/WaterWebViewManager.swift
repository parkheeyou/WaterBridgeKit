#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit

/// WaterWebView가 생성한 웹뷰만 식별합니다. 일반 WKWebView는 이벤트 대상으로 선택하지 않습니다.
@MainActor
final class WaterHostedWebView: WKWebView {
    var isBridgeActive = true
}

/// SwiftUI WaterWebView 내부의 실제 WKWebView를 조회합니다.
@MainActor
public enum WaterWebViewManager {
    /// 기존 currentViewController와 같이 네이티브 모달 아래의 기본 웹 화면을 조회합니다.
    /// 여러 활성 창 또는 여러 웹뷰로 대상이 모호한 경우 nil을 반환합니다.
    /// 멀티 윈도우 앱은 대상 window를 명시하세요.
    public static func currentWebView(in window: UIWindow? = nil) -> WKWebView? {
        guard let window = window ?? WaterViewControllerManager.activeWindow(),
              !window.isHidden, window.alpha > 0,
              let controller = WaterViewControllerManager.currentViewController(in: window),
              let rootView = controller.viewIfLoaded else { return nil }
        let candidates = webViews(in: rootView, window: window)
        return candidates.count == 1 ? candidates.first : nil
    }

    private static func webViews(in view: UIView, window: UIWindow) -> [WKWebView] {
        guard !view.isHidden, view.alpha > 0, view.window === window else { return [] }
        if let webView = view as? WaterHostedWebView {
            return webView.isBridgeActive ? [webView] : []
        }
        return view.subviews.flatMap { webViews(in: $0, window: window) }
    }
}
#endif
