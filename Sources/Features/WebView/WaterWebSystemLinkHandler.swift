#if canImport(UIKit) && canImport(WebKit)
import UIKit

/// 전화/문자 링크는 브릿지 라우터를 거치지 않고 시스템 URL 처리기로 전달합니다.
@MainActor
final class WaterWebSystemLinkHandler {
    private let open: @MainActor (URL) async -> Bool
    private let onFailure: @MainActor (String) -> Void
    private var openingTask: Task<Void, Never>?

    init(
        open: @escaping @MainActor (URL) async -> Bool = {
            await UIApplication.shared.open($0, options: [:])
        },
        onFailure: @escaping @MainActor (String) -> Void
    ) {
        self.open = open
        self.onFailure = onFailure
    }

    /// true이면 WebKit 탐색을 취소해야 합니다. 하위 프레임의 시스템 앱 호출은 차단합니다.
    @discardableResult
    func handle(_ url: URL, fromMainFrame: Bool) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["tel", "sms"].contains(scheme) else { return false }
        guard fromMainFrame, openingTask == nil else { return true }
        openingTask = Task { [weak self] in
            guard let self else { return }
            defer { openingTask = nil }
            let opened = await open(url)
            guard !Task.isCancelled else { return }
            if !opened {
                onFailure(scheme == "tel"
                    ? "전화 앱을 열 수 없습니다. 이 기기에서 전화 기능을 사용할 수 있는지 확인해 주세요."
                    : "문자 앱을 열 수 없습니다. 이 기기에서 문자 기능을 사용할 수 있는지 확인해 주세요.")
            }
        }
        return true
    }

    func cancel() {
        openingTask?.cancel()
    }
}
#endif
