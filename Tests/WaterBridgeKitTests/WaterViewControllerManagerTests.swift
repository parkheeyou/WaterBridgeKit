#if canImport(UIKit)
import UIKit
import XCTest
@testable import WaterBridgeKit

final class WaterViewControllerManagerTests: XCTestCase {
    @MainActor
    func testCurrentExcludesModalsWhileTopIncludesNavigationAndAlert() {
        let page = PresentationStub()
        let navigation = UINavigationController(rootViewController: page)
        let tab = UITabBarController()
        tab.viewControllers = [UIViewController(), navigation]
        tab.selectedIndex = 1
        let modalPage = PresentationStub()
        let modal = UINavigationController(rootViewController: modalPage)
        let alert = UIAlertController(title: "Test", message: "message", preferredStyle: .alert)
        page.simulatedPresented = modal
        modalPage.simulatedPresented = alert
        let window = makeWindow(root: tab)
        XCTAssertTrue(WaterViewControllerManager.currentViewController(in: window) === page)
        XCTAssertTrue(WaterViewControllerManager.topViewController(in: window) === alert)
        XCTAssertTrue(WaterViewControllerManager.rootViewController(in: window) === tab)
    }

    @MainActor
    func testSplitUsesDetailAndEmptyContainersRemainSafe() {
        let split = UISplitViewController(style: .doubleColumn)
        let detail = UIViewController()
        split.viewControllers = [UIViewController(), UINavigationController(rootViewController: detail)]
        XCTAssertTrue(WaterViewControllerManager.currentViewController(from: split) === detail)
        for container in [UINavigationController(), UITabBarController()] as [UIViewController] {
            XCTAssertTrue(WaterViewControllerManager.currentViewController(from: container) === container)
            XCTAssertTrue(WaterViewControllerManager.topViewController(from: container) === container)
        }
    }

    @MainActor
    func testDismissAllResetsEveryTabButPreservesSelectionRootAndOtherWindow() async throws {
        let first = UINavigationController(rootViewController: UIViewController())
        let second = UINavigationController(rootViewController: UIViewController())
        first.pushViewController(UIViewController(), animated: false)
        second.pushViewController(UIViewController(), animated: false)
        let tab = UITabBarController()
        tab.viewControllers = [first, second]
        tab.selectedIndex = 1
        let window = makeWindow(root: tab)
        let other = UINavigationController(rootViewController: UIViewController())
        other.pushViewController(UIViewController(), animated: false)
        let otherWindow = makeWindow(root: other)
        try await WaterViewControllerManager.dismissAll(in: window, animated: false)
        XCTAssertTrue(window.rootViewController === tab)
        XCTAssertEqual(tab.selectedIndex, 1)
        XCTAssertEqual(first.viewControllers.count, 1)
        XCTAssertEqual(second.viewControllers.count, 1)
        XCTAssertEqual(other.viewControllers.count, 2)
        XCTAssertTrue(otherWindow.rootViewController === other)
    }

    @MainActor
    func testDismissesFromLowestPresenterAndCanRepeatWhenNothingIsOpen() async throws {
        let root = PresentationStub()
        let modal = PresentationStub()
        root.simulatedPresented = modal
        modal.simulatedPresented = UIViewController()
        let window = makeWindow(root: root)
        try await WaterViewControllerManager.dismissAll(in: window, animated: false)
        XCTAssertEqual(root.dismissCalls, 1)
        XCTAssertEqual(modal.dismissCalls, 0)
        XCTAssertNil(root.presentedViewController)
        XCTAssertTrue(window.rootViewController === root)
        try await WaterViewControllerManager.dismissAll(in: window, animated: false)
        XCTAssertEqual(root.dismissCalls, 1)
    }

    @MainActor
    func testNoRootAndTransitionFailuresDoNotChangeScreens() async {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        XCTAssertNil(WaterViewControllerManager.currentViewController(in: window))
        do {
            try await WaterViewControllerManager.dismissAll(in: window)
            XCTFail("Expected missing root")
        } catch WaterViewControllerError.noRootViewController { }
        catch { XCTFail("Unexpected: \(error)") }
        let root = PresentationStub()
        root.simulatesTransition = true
        root.simulatedPresented = UIViewController()
        window.rootViewController = root
        do {
            try await WaterViewControllerManager.dismissAll(in: window)
            XCTFail("Expected transition rejection")
        } catch WaterViewControllerError.transitionInProgress { }
        catch { XCTFail("Unexpected: \(error)") }
        XCTAssertEqual(root.dismissCalls, 0)
    }

    @MainActor
    func testRootReplacementDuringDismissalIsPreserved() async {
        let root = PresentationStub()
        root.simulatedPresented = UIViewController()
        let window = makeWindow(root: root)
        let replacement = UINavigationController(rootViewController: UIViewController())
        replacement.pushViewController(UIViewController(), animated: false)
        root.onDismiss = { window.rootViewController = replacement }
        do {
            try await WaterViewControllerManager.dismissAll(in: window, animated: false)
            XCTFail("Expected root replacement")
        } catch WaterViewControllerError.rootViewControllerChanged { }
        catch { XCTFail("Unexpected: \(error)") }
        XCTAssertTrue(window.rootViewController === replacement)
        XCTAssertEqual(replacement.viewControllers.count, 2)
    }

    @MainActor
    func testCustomContainerChildrenAreNotPopped() async throws {
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.pushViewController(UIViewController(), animated: false)
        root.addChild(navigation)
        navigation.didMove(toParent: root)
        let window = makeWindow(root: root)
        try await WaterViewControllerManager.dismissAll(in: window, animated: false)
        XCTAssertTrue(WaterViewControllerManager.currentViewController(in: window) === root)
        XCTAssertEqual(navigation.viewControllers.count, 2)
    }

    @MainActor
    func testOverlappingDismissalIsRejectedAndLockIsReleased() async throws {
        let root = PresentationStub()
        root.simulatedPresented = UIViewController()
        root.holdCompletion = true
        let window = makeWindow(root: root)
        let first = Task { try await WaterViewControllerManager.dismissAll(in: window, animated: false) }
        for _ in 0..<100 {
            if root.heldCompletion != nil { break }
            await Task.yield()
        }
        XCTAssertNotNil(root.heldCompletion)
        do {
            try await WaterViewControllerManager.dismissAll(in: window, animated: false)
            XCTFail("Expected overlapping dismissal rejection")
        } catch WaterViewControllerError.dismissalInProgress { }
        root.heldCompletion?()
        root.heldCompletion = nil
        try await first.value
        try await WaterViewControllerManager.dismissAll(in: window, animated: false)
    }

    @MainActor
    private func makeWindow(root: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = root
        return window
    }
}

@MainActor
private final class PresentationStub: UIViewController {
    var simulatedPresented: UIViewController?
    var simulatesTransition = false
    var dismissCalls = 0
    var holdCompletion = false
    var heldCompletion: (() -> Void)?
    var onDismiss: (() -> Void)?

    override var presentedViewController: UIViewController? { simulatedPresented }
    override var isBeingPresented: Bool { simulatesTransition }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCalls += 1
        simulatedPresented = nil
        // UIWindow의 root 교체가 dismiss를 다시 부를 수 있어 테스트 훅은 한 번만 실행합니다.
        let action = onDismiss
        onDismiss = nil
        action?()
        if holdCompletion { heldCompletion = completion }
        else { completion?() }
    }
}
#endif
