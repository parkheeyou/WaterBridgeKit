#if canImport(WebKit)
import WaterBridgeCore
import WebKit

/// 네이티브 브릿지 응답을 웹에서 전달한 callback 함수로 반환합니다.
@MainActor
enum WaterBridgeCallbackResponder {
    static func respond(
        api: String,
        callback: String,
        response: Any,
        in webView: WKWebView
    ) {
        Task { @MainActor in
            do {
                _ = try await webView.callAsyncJavaScript(
                    """
                    const callbackFunction = globalThis[callbackName];
                    if (typeof callbackFunction !== "function") {
                      throw new Error("Bridge callback not found: " + callbackName);
                    }
                    callbackFunction(response);
                    return true;
                    """,
                    arguments: [
                        "callbackName": callback,
                        "response": response
                    ],
                    in: nil,
                    contentWorld: .page
                )
                WaterBridgeLogger.callbackCompleted(
                    api: api,
                    callback: callback
                )

            } catch {
                WaterBridgeLogger.callbackFailed(
                    api: api,
                    callback: callback,
                    error: error
                )
            }
        }
    }
}
#endif
