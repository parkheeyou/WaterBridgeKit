#if canImport(UIKit) && canImport(WebKit)
import SwiftUI
import WebKit

struct WaterWebViewRepresentable: UIViewRepresentable {
    static let bridgeChannel = "waterBridge"

    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?
    let onBridgeMessage: WaterBridgeMessageHandler

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.addScriptMessageHandler(
            context.coordinator,
            contentWorld: .page,
            name: Self.bridgeChannel
        )
        userContentController.addUserScript(Self.bridgeBootstrapScript)

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isInspectable = true
        WaterBridgeLogger.webViewLoadRequested(url: url)
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(
            forName: bridgeChannel
        )
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandlerWithReply {
        var parent: WaterWebViewRepresentable
        private var loadStartedAt: Date?

        init(_ parent: WaterWebViewRepresentable) {
            self.parent = parent
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage,
            replyHandler: @escaping @MainActor (Any?, String?) -> Void
        ) {
            guard message.name == WaterWebViewRepresentable.bridgeChannel,
                  message.frameInfo.isMainFrame else {
                WaterBridgeLogger.rejected(
                    reason: "허용되지 않은 채널 또는 프레임입니다.",
                    body: message.body
                )
                replyHandler(nil, "허용되지 않은 브릿지 메시지입니다.")
                return
            }

            let bridgeMessage = WaterBridgeMessage(
                channel: message.name,
                body: message.body,
                sourceURL: message.frameInfo.request.url
            )
            WaterBridgeLogger.received(bridgeMessage)
            parent.onBridgeMessage(bridgeMessage)

            guard let api = bridgeMessage.api else {
                WaterBridgeLogger.rejected(
                    reason: "브릿지 API를 확인할 수 없습니다.",
                    body: bridgeMessage.body
                )
                replyHandler(nil, nil)
                return
            }

            let response = WaterBridgeRouter.response(for: bridgeMessage)
            WaterBridgeLogger.responded(api: api, response: response)
            replyHandler(response, nil)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            loadStartedAt = Date()
            parent.isLoading = true
            parent.errorMessage = nil
            WaterBridgeLogger.webViewNavigationStarted(url: webView.url ?? parent.url)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            WaterBridgeLogger.webViewContentCommitted(url: webView.url)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            WaterBridgeLogger.webViewLoadFinished(
                url: webView.url,
                elapsedTime: elapsedTime
            )
            loadStartedAt = nil
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            show(error, in: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            show(error, in: webView)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                WaterBridgeLogger.webViewLoadRequested(url: url)
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        private var elapsedTime: TimeInterval? {
            loadStartedAt.map { Date().timeIntervalSince($0) }
        }

        private func show(_ error: Error, in webView: WKWebView) {
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                WaterBridgeLogger.webViewLoadCancelled(url: webView.url)
                loadStartedAt = nil
                return
            }

            WaterBridgeLogger.webViewLoadFailed(
                url: webView.url ?? parent.url,
                error: error,
                elapsedTime: elapsedTime
            )
            loadStartedAt = nil
            parent.isLoading = false
            parent.errorMessage = error.localizedDescription
        }
    }

    private static let bridgeBootstrapScript = WKUserScript(
        source: """
        (() => {
          const call = function(api, payload) {
            return window.webkit.messageHandlers.waterBridge.postMessage({
              api: api,
              payload: payload === undefined ? null : payload
            });
          };

          const callWithCallback = function(api, params, callback) {
            return call(api, params)
              .then((response) => {
                if (typeof callback === "function") callback(response);
                return response;
              })
              .catch((error) => {
                const response = {
                  status: {
                    code: "9999",
                    message: error && error.message
                      ? error.message
                      : "브릿지 호출에 실패했습니다."
                  },
                  data: null
                };
                if (typeof callback === "function") callback(response);
                return response;
              });
          };

          window.WaterBridge = Object.freeze({
            call: call,
            postMessage: function(action, payload) {
              return window.webkit.messageHandlers.waterBridge.postMessage({
              action: action,
              payload: payload === undefined ? null : payload
            });
            },
            routeApiList: function(params, callback) {
              return callWithCallback(
                "water://routeApiList",
                params || {},
                callback
              );
            }
          });
        })();
        """,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )
}
#endif
