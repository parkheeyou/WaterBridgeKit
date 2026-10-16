import SwiftUI

struct WaterBridgeAlertNotice: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor
final class WaterBridgeAlertPresentation: ObservableObject {
    @Published var notice: WaterBridgeAlertNotice?

    func present(_ message: String) -> Bool {
        guard notice == nil else { return false }
        notice = .init(message: message)
        return true
    }
}
