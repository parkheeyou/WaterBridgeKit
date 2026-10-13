#if os(iOS)
import Foundation

/// 앱 사용 중 위치 권한을 요청합니다. 백그라운드 위치 권한은 포함하지 않습니다.
public enum WaterPermission: String, CaseIterable, Identifiable, Sendable {
    case camera, microphone, location, photos

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .camera: "카메라"
        case .microphone: "마이크"
        case .location: "위치"
        case .photos: "사진 라이브러리"
        }
    }

    public var usageDescriptionKey: String {
        switch self {
        case .camera: "NSCameraUsageDescription"
        case .microphone: "NSMicrophoneUsageDescription"
        case .location: "NSLocationWhenInUseUsageDescription"
        case .photos: "NSPhotoLibraryUsageDescription"
        }
    }
}

public enum WaterPermissionStatus: String, Sendable {
    case notDetermined, authorized, limited, denied, restricted, servicesDisabled

    /// 사진의 제한된 접근도 사용할 수 있는 권한으로 취급합니다.
    public var isGranted: Bool { self == .authorized || self == .limited }

    public var title: String {
        switch self {
        case .notDetermined: "아직 요청하지 않음"
        case .authorized: "허용됨"
        case .limited: "선택한 사진만 허용됨"
        case .denied: "거부됨"
        case .restricted: "기기 정책으로 제한됨"
        case .servicesDisabled: "위치 서비스 꺼짐"
        }
    }
}

public enum WaterPermissionError: LocalizedError {
    case missingUsageDescription(String)
    case appNotActive
    case requestInProgress

    public var errorDescription: String? {
        switch self {
        case let .missingUsageDescription(key): "앱의 Info.plist에 \(key) 사용 목적을 설정해야 합니다."
        case .appNotActive: "앱이 활성화된 상태에서 권한을 요청하세요."
        case .requestInProgress: "다른 권한 요청이 진행 중입니다. 완료 후 다시 시도하세요."
        }
    }
}
#endif
