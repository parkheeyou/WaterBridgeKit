#if canImport(UIKit) && canImport(WebKit)
import WebKit

/// WebKit의 delegate는 WaterBridgeKit이 관리하며 앱에는 필요한 이벤트만 전달합니다.
@MainActor
public struct WaterWebViewLifecycle {
    public let onCreated: @MainActor (WKWebView) -> Void
    public let onFinished: @MainActor (WKWebView) -> Void
    public let onFailed: @MainActor (WKWebView, Error) -> Void
    public let onDismantle: @MainActor (WKWebView) -> Void

    public init(
        onCreated: @escaping @MainActor (WKWebView) -> Void = { _ in },
        onFinished: @escaping @MainActor (WKWebView) -> Void = { _ in },
        onFailed: @escaping @MainActor (WKWebView, Error) -> Void = { _, _ in },
        onDismantle: @escaping @MainActor (WKWebView) -> Void = { _ in }
    ) {
        self.onCreated = onCreated
        self.onFinished = onFinished
        self.onFailed = onFailed
        self.onDismantle = onDismantle
    }
}
#endif
