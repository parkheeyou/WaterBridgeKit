#if os(iOS)
import AVFoundation
import CoreLocation
import Photos
import SwiftUI
import UIKit
import WaterBridgeCore

/// 시스템 권한 요청과 설정 안내를 담당합니다. 앱에서 하나의 인스턴스를 유지하세요.
@MainActor
public final class WaterPermissionManager: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published public private(set) var statuses: [WaterPermission: WaterPermissionStatus] = [:]
    @Published public private(set) var isRequesting = false
    @Published var notice: WaterPermissionNotice?

    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.delegate = self
        return manager
    }()
    private var locationContinuation: CheckedContinuation<Void, Never>?

    public override init() { super.init() }

    /// 현재 상태를 읽습니다. 시스템 권한 창을 띄우지 않습니다.
    public func status(for permission: WaterPermission) async -> WaterPermissionStatus {
        let status: WaterPermissionStatus
        switch permission {
        case .camera:
            status = Self.captureStatus(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:
            status = Self.captureStatus(AVCaptureDevice.authorizationStatus(for: .audio))
        case .photos:
            switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
            case .notDetermined: status = .notDetermined
            case .authorized: status = .authorized
            case .limited: status = .limited
            case .denied: status = .denied
            case .restricted: status = .restricted
            @unknown default: status = .restricted
            }
        case .location:
            // 이 조회는 동기 IPC가 발생할 수 있어 메인 스레드 밖에서 실행합니다.
            let enabled = await Task.detached { CLLocationManager.locationServicesEnabled() }.value
            if !enabled {
                status = .servicesDisabled
            } else {
                switch locationManager.authorizationStatus {
                case .notDetermined: status = .notDetermined
                case .authorizedAlways, .authorizedWhenInUse: status = .authorized
                case .denied: status = .denied
                case .restricted: status = .restricted
                @unknown default: status = .restricted
                }
            }
        }
        statuses[permission] = status
        return status
    }

    public func refresh() async {
        for permission in WaterPermission.allCases { _ = await status(for: permission) }
    }

    /// 미결정 상태에서만 시스템 권한 창을 표시합니다. 거부된 권한은 재요청하지 않습니다.
    public func request(_ permission: WaterPermission) async throws -> WaterPermissionStatus {
        guard !isRequesting else { throw WaterPermissionError.requestInProgress }
        isRequesting = true
        defer { isRequesting = false }
        let current = await status(for: permission)
        guard current == .notDetermined else { return current }
        try Task.checkCancellation()
        guard UIApplication.shared.applicationState == .active else { throw WaterPermissionError.appNotActive }
        let key = permission.usageDescriptionKey
        guard let purpose = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WaterPermissionError.missingUsageDescription(key)
        }

        switch permission {
        case .camera: _ = await AVCaptureDevice.requestAccess(for: .video)
        case .microphone: _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .photos: _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        case .location:
            await withCheckedContinuation { continuation in
                locationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        }
        let result = await status(for: permission)
        WaterDebugLogger.event("\(permission.title) 권한 요청 완료: \(result.rawValue)")
        return result
    }

    /// `.waterPermissionAlerts`와 함께 사용합니다. 미허용 시 상태에 맞는 안내를 표시합니다.
    @discardableResult
    public func ensurePermission(_ permission: WaterPermission) async -> Bool {
        // 연속 탭은 무시하여 진행 중인 시스템 창과 앱 안내가 겹치지 않게 합니다.
        guard !isRequesting else { return false }
        do {
            let result = try await request(permission)
            guard !Task.isCancelled else { return false }
            if result.isGranted { return true }
            notice = WaterPermissionNotice.required(for: permission, status: result)
        } catch is CancellationError {
            return false
        } catch {
            notice = .init(title: "권한 요청을 완료하지 못했습니다", message: error.localizedDescription, offersSettings: false)
        }
        return false
    }

    /// 공개된 iOS 앱 설정 URL을 사용합니다. 호출 결과가 false이면 설정 열기에 실패했습니다.
    @discardableResult
    public func openSettings() async -> Bool {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return false }
        let opened = await UIApplication.shared.open(url)
        if !opened {
            notice = .init(title: "설정을 열 수 없습니다", message: "설정 앱에서 직접 이 앱의 권한을 변경해 주세요.", offersSettings: false)
        }
        return opened
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        let continuation = locationContinuation
        locationContinuation = nil
        continuation?.resume()
    }

    private static func captureStatus(_ status: AVAuthorizationStatus) -> WaterPermissionStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }
}

struct WaterPermissionNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let offersSettings: Bool

    static func required(for permission: WaterPermission, status: WaterPermissionStatus) -> Self? {
        switch status {
        case .denied:
            .init(title: "\(permission.title) 권한이 필요합니다", message: "설정에서 이 앱의 \(permission.title) 접근을 허용해 주세요.", offersSettings: true)
        case .servicesDisabled:
            .init(title: "위치 서비스가 꺼져 있습니다", message: "설정 > 개인정보 보호 및 보안 > 위치 서비스에서 위치 서비스를 켜고 이 앱의 위치 접근을 허용해 주세요.", offersSettings: true)
        case .restricted:
            .init(title: "\(permission.title) 접근이 제한되어 있습니다", message: "스크린 타임 또는 기기 관리 정책을 확인해 주세요. 앱 설정만으로는 변경할 수 없을 수 있습니다.", offersSettings: false)
        case .authorized, .limited, .notDetermined:
            nil
        }
    }
}
#endif
