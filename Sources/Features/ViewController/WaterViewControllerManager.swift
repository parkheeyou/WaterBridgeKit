#if canImport(UIKit)
import UIKit

public enum WaterViewControllerError: Error, LocalizedError {
    case noTargetWindow
    case noRootViewController
    case transitionInProgress
    case dismissalInProgress
    case rootViewControllerChanged

    public var errorDescription: String? {
        switch self {
        case .noTargetWindow: "대상 창을 결정할 수 없습니다. 활성 창을 명시해 주세요."
        case .noRootViewController: "대상 창에 루트 ViewController가 없습니다."
        case .transitionInProgress: "화면 전환이 진행 중입니다. 전환 완료 후 다시 시도하세요."
        case .dismissalInProgress: "이 창의 전체 닫기가 이미 진행 중입니다."
        case .rootViewControllerChanged: "닫기 도중 루트 화면이 변경되었습니다. 새 루트 화면은 유지합니다."
        }
    }
}

/// UIWindow를 기준으로 UIKit 화면을 조회하고 모달·내비게이션 스택을 정리합니다.
@MainActor
public enum WaterViewControllerManager {
    private static var dismissingWindows: Set<ObjectIdentifier> = []

    /// 활성 scene에 key window가 하나만 있을 때 반환합니다. 여러 창이면 명시적으로 선택하세요.
    public static func activeWindow(in scene: UIWindowScene? = nil) -> UIWindow? {
        let scenes = scene.map { [$0] } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let candidates = scenes.filter { $0.activationState == .foregroundActive }
            .compactMap(\.keyWindow).filter { !$0.isHidden && $0.alpha > 0 && $0.windowLevel == .normal }
        return candidates.count == 1 ? candidates.first : nil
    }

    public static func rootViewController(in window: UIWindow? = nil) -> UIViewController? {
        (window ?? activeWindow())?.rootViewController
    }

    /// 모달을 따라가지 않고 루트의 선택된 탭·내비게이션 마지막 화면을 반환합니다.
    public static func currentViewController(in window: UIWindow? = nil) -> UIViewController? {
        guard let root = rootViewController(in: window) else { return nil }
        return currentViewController(from: root)
    }

    /// presented 화면과 알럿까지 따라가 실제 맨 앞의 ViewController를 반환합니다.
    public static func topViewController(in window: UIWindow? = nil) -> UIViewController? {
        guard let root = rootViewController(in: window) else { return nil }
        return topViewController(from: root)
    }

    /// 컨테이너만 해석합니다. 커스텀 컨테이너는 자신을 반환합니다.
    public static func currentViewController(from root: UIViewController) -> UIViewController {
        if let child = selectedChild(of: root) { return currentViewController(from: child) }
        return root
    }

    public static func topViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController, !presented.isBeingDismissed {
            return topViewController(from: presented)
        }
        if let child = selectedChild(of: root) { return topViewController(from: child) }
        return root
    }

    /// 루트를 유지하고 모든 모달을 닫은 후 각 UIKit navigation을 루트로 되돌립니다.
    /// animated는 모달 닫기에 적용하며 navigation 스택은 애니메이션 없이 정리합니다.
    /// SwiftUI NavigationPath/시트 binding은 앱에서 별도로 변경해야 합니다.
    public static func dismissAll(in window: UIWindow? = nil, animated: Bool = true) async throws {
        guard let window = window ?? activeWindow() else { throw WaterViewControllerError.noTargetWindow }
        guard let root = window.rootViewController else { throw WaterViewControllerError.noRootViewController }
        let identity = ObjectIdentifier(window)
        guard !dismissingWindows.contains(identity) else { throw WaterViewControllerError.dismissalInProgress }
        guard !hasTransition(in: root) else { throw WaterViewControllerError.transitionInProgress }
        dismissingWindows.insert(identity)
        defer { dismissingWindows.remove(identity) }

        for presenter in presentationOwners(in: root) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                presenter.dismiss(animated: animated) { continuation.resume() }
            }
            guard window.rootViewController === root else { throw WaterViewControllerError.rootViewControllerChanged }
        }
        resetNavigation(in: root)
    }

    private static func selectedChild(of controller: UIViewController) -> UIViewController? {
        if let navigation = controller as? UINavigationController { return navigation.topViewController }
        if let tab = controller as? UITabBarController { return tab.selectedViewController }
        // Split View는 마지막(detail) 열을 기준으로 조회합니다.
        if let split = controller as? UISplitViewController { return split.viewControllers.last }
        return nil
    }

    private static func hasTransition(in controller: UIViewController) -> Bool {
        if controller.isBeingPresented || controller.isBeingDismissed || controller.transitionCoordinator != nil { return true }
        if let presented = controller.presentedViewController, hasTransition(in: presented) { return true }
        return controller.children.contains { hasTransition(in: $0) }
    }

    private static func presentationOwners(in controller: UIViewController) -> [UIViewController] {
        // 아래쪽 presenter에서 dismiss하면 그 위의 모달도 함께 닫힙니다.
        if controller.presentedViewController != nil { return [controller] }
        return controller.children.flatMap { presentationOwners(in: $0) }
    }

    private static func resetNavigation(in controller: UIViewController) {
        if let navigation = controller as? UINavigationController {
            navigation.popToRootViewController(animated: false)
            if let root = navigation.viewControllers.first { resetNavigation(in: root) }
        } else if let tab = controller as? UITabBarController {
            for child in tab.viewControllers ?? [] { resetNavigation(in: child) }
        } else if let split = controller as? UISplitViewController {
            for child in split.viewControllers { resetNavigation(in: child) }
        }
        // 커스텀/SwiftUI 컨테이너의 내부 child 스택은 임의로 변경하지 않습니다.
    }
}
#endif
