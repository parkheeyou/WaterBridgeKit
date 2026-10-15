#if canImport(UIKit) && canImport(WebKit)
import SwiftUI
import UIKit

struct WaterBridgePresentedDestination: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class WaterBridgeWebNavigation: ObservableObject {
    @Published var webDestination: WaterBridgePresentedDestination?
    @Published var errorMessage: String?
    private var isOpeningExternal = false
    private let openExternal: @MainActor (URL) async -> Bool

    init(openExternal: @escaping @MainActor (URL) async -> Bool = {
        await UIApplication.shared.open($0, options: [:])
    }) {
        self.openExternal = openExternal
    }

    func request(_ destination: WaterBridgeWebDestination) -> Bool {
        guard !isOpeningExternal, webDestination == nil else { return false }
        switch destination.target {
        case .webView:
            webDestination = .init(url: destination.url)
        case .safari:
            isOpeningExternal = true
            Task { [weak self] in
                guard let self else { return }
                let opened = await openExternal(destination.url)
                isOpeningExternal = false
                if !opened { errorMessage = "외부 브라우저에서 페이지를 열 수 없습니다." }
            }
        }
        return true
    }
}

struct WaterBridgePresentedWebView: View {
    let url: URL
    let configuration: WaterBridgeConfiguration
    let onBridgeMessage: WaterBridgeMessageHandler
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WaterWebView(url: url, configuration: configuration, onBridgeMessage: onBridgeMessage)
                .navigationTitle(url.host ?? "웹뷰")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { dismiss() }
                    }
                }
        }
    }
}
#endif
