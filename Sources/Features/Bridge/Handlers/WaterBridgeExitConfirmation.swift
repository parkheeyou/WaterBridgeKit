import Darwin
import SwiftUI
import WaterBridgeCore

/// 웹뷰마다 별도로 소유하며 사용자가 확인한 경우에만 종료합니다.
@MainActor
final class WaterBridgeExitConfirmation: ObservableObject {
    @Published var isPresented = false
    private var hasPendingRequest = false
    private let terminate: @MainActor () -> Void

    init(terminate: @escaping @MainActor () -> Void = { Darwin.exit(EXIT_SUCCESS) }) {
        self.terminate = terminate
    }

    func request() {
        guard !hasPendingRequest else { return }
        hasPendingRequest = true
        isPresented = true
        WaterDebugLogger.event("앱 종료 확인 요청")
    }

    func cancel() {
        hasPendingRequest = false
        isPresented = false
        WaterDebugLogger.event("앱 종료 취소")
    }

    func confirm() {
        // SwiftUI는 버튼 action 전에 isPresented를 false로 바꿀 수 있습니다.
        guard hasPendingRequest else { return }
        hasPendingRequest = false
        isPresented = false
        WaterDebugLogger.event("사용자가 앱 종료를 확인했습니다.")
        terminate()
    }
}
