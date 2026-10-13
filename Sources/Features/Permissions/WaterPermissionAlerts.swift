#if os(iOS)
import SwiftUI

private struct WaterPermissionAlertsModifier: ViewModifier {
    @ObservedObject var manager: WaterPermissionManager
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .alert(item: $manager.notice) { notice in
                if notice.offersSettings {
                    Alert(title: Text(notice.title), message: Text(notice.message),
                          primaryButton: .default(Text("설정으로 이동")) {
                              Task { await manager.openSettings() }
                          }, secondaryButton: .cancel(Text("취소")))
                } else {
                    Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("확인")))
                }
            }
            .task { await manager.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await manager.refresh() } }
            }
    }
}

public extension View {
    /// 권한 안내를 표시하고 설정에서 돌아왔을 때 상태를 다시 읽습니다.
    func waterPermissionAlerts(using manager: WaterPermissionManager) -> some View {
        modifier(WaterPermissionAlertsModifier(manager: manager))
    }
}
#endif
