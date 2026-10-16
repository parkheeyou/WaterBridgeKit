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

    @StateObject private var alertPresentation = WaterBridgeAlertPresentation()
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
                onOpenRequested: { webNavigation.request($0) },
                onAlertRequested: {
                    guard !exitConfirmation.isPresented,
                          webNavigation.webDestination == nil,
                          webNavigation.errorMessage == nil else { return false }
                    return alertPresentation.present($0)
                }
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
        .sheet(item: $webNavigation.webDestination) { destination in
            WaterBridgePresentedWebView(
                url: destination.url, configuration: configuration,
                onBridgeMessage: onBridgeMessage
            )
        }
        .waterDebugConsole(isEnabled: configuration.showsDebugConsole)
        .alert(presentedAlert?.title ?? "알림", isPresented: Binding(
            get: { presentedAlert != nil },
            set: { if !$0 { dismissPresentedAlert() } }
        ), presenting: presentedAlert) { alert in
            switch alert {
            case .exit:
                Button("취소", role: .cancel) { exitConfirmation.cancel() }
                Button("종료", role: .destructive) { exitConfirmation.confirm() }
            case .message, .error:
                Button("확인", role: .cancel) {}
            }
        } message: { alert in
            if let message = alert.message { Text(message) }
        }
    }

    // 메시지·종료·외부 열기 실패 알림이 하나의 시스템 alert presenter를 공유합니다.
    private var presentedAlert: PresentedAlert? {
        if let notice = alertPresentation.notice { return .message(notice.message) }
        if exitConfirmation.isPresented { return .exit }
        if let error = webNavigation.errorMessage { return .error(error) }
        return nil
    }

    private func dismissPresentedAlert() {
        if alertPresentation.notice != nil { alertPresentation.notice = nil }
        else if exitConfirmation.isPresented { exitConfirmation.isPresented = false }
        else { webNavigation.errorMessage = nil }
    }

    private enum PresentedAlert {
        case message(String), exit, error(String)

        var title: String {
            switch self {
            case .message: "알림"
            case .exit: "앱을 종료하겠습니까?"
            case .error: "페이지를 열 수 없습니다"
            }
        }

        var message: String? {
            switch self {
            case let .message(text), let .error(text): text
            case .exit: nil
            }
        }
    }
}
#endif
