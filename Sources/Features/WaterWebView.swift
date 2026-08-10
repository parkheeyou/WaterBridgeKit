#if canImport(UIKit) && canImport(WebKit)
import SwiftUI

/// URL을 앱 내부에서 표시하고 JavaScript 브릿지 메시지를 전달하는 SwiftUI 웹뷰입니다.
///
/// 웹에서는 다음 두 방식 중 하나로 네이티브를 호출할 수 있습니다.
/// ```javascript
/// window.WaterBridge.routeApiList({}, (response) => {
///   console.log(response.status);
///   console.log(response.data);
/// });
///
/// const response = await window.WaterBridge.call("water://routeApiList");
///
/// const directResponse = await window.webkit.messageHandlers.waterBridge
///   .postMessage("water://routeApiList");
///
/// console.log(response.status.code); // "0000"
/// console.log(response.data);        // 지원 API 목록
/// ```
public struct WaterWebView: View {
    private let url: URL
    private let onBridgeMessage: WaterBridgeMessageHandler

    @State private var isLoading = true
    @State private var errorMessage: String?

    public init(
        url: URL,
        onBridgeMessage: @escaping WaterBridgeMessageHandler = { _ in }
    ) {
        self.url = url
        self.onBridgeMessage = onBridgeMessage
    }

    public var body: some View {
        ZStack {
            WaterWebViewRepresentable(
                url: url,
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                onBridgeMessage: onBridgeMessage
            )

            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }

            if let errorMessage {
                ContentUnavailableView(
                    "페이지를 열 수 없습니다",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
                .padding()
                .background(.background)
            }
        }
    }
}
#endif
