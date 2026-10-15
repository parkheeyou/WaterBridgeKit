#if canImport(UIKit) && canImport(WebKit)
import SwiftUI
import WaterBridgeCore

/// URL을 앱 내부에서 표시하고 JavaScript 브릿지 메시지를 전달하는 SwiftUI 웹뷰입니다.
///
/// 웹에서는 다음 두 방식 중 하나로 네이티브를 호출할 수 있습니다.
/// ```javascript
/// window.Bridge.routeApiList({}, (response) => {
///   console.log(response.status);
///   console.log(response.data);
/// });
///
/// const response = await window.Bridge.call("water://routeApiList");
///
/// const directResponse = await window.webkit.messageHandlers.Bridge
///   .postMessage("water://routeApiList");
///
/// console.log(response.status.code); // "0000"
/// console.log(response.data);        // 지원 API 목록
/// ```
public struct WaterWebView: View {
    private let url: URL
    private let configuration: WaterBridgeConfiguration
    private let onBridgeMessage: WaterBridgeMessageHandler

    @StateObject private var webNavigation = WaterBridgeWebNavigation()
    @StateObject private var exitConfirmation = WaterBridgeExitConfirmation()
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init(
        url: URL,
        configuration: WaterBridgeConfiguration = .init(),
        onBridgeMessage: @escaping WaterBridgeMessageHandler = { _ in }
    ) {
        self.url = url
        self.configuration = configuration
        self.onBridgeMessage = onBridgeMessage
    }

    public var body: some View {
        ZStack {
            WaterWebViewRepresentable(
                url: url,
                bridgeConfiguration: configuration,
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                onBridgeMessage: onBridgeMessage,
                onExitRequested: { exitConfirmation.request() },
                onOpenRequested: { webNavigation.request($0) }
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
        .overlay {
            Color.clear
                .allowsHitTesting(false)
                .alert("페이지를 열 수 없습니다", isPresented: Binding(
                    get: { webNavigation.errorMessage != nil },
                    set: { if !$0 { webNavigation.errorMessage = nil } }
                )) {
                    Button("확인", role: .cancel) { webNavigation.errorMessage = nil }
                } message: {
                    Text(webNavigation.errorMessage ?? "")
                }
        }
        .sheet(item: $webNavigation.webDestination) { destination in
            WaterBridgePresentedWebView(
                url: destination.url, configuration: configuration,
                onBridgeMessage: onBridgeMessage
            )
        }
        .waterDebugConsole(isEnabled: configuration.showsDebugConsole)
        .alert("앱을 종료하겠습니까?", isPresented: $exitConfirmation.isPresented) {
            Button("취소", role: .cancel) { exitConfirmation.cancel() }
            Button("종료", role: .destructive) { exitConfirmation.confirm() }
        }
    }
}
#endif
