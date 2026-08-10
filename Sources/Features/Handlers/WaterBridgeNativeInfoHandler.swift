import Foundation
import WaterBridgeCore

#if canImport(UIKit)
import UIKit
#endif

/// 앱과 기기의 기본 네이티브 정보를 반환합니다.
@MainActor
enum WaterBridgeNativeInfoHandler {
    static func handle(_ message: WaterBridgeMessage) -> Any {
        #if canImport(UIKit)
        let data: [String: Any] = [
            "platform": UIDevice.current.systemName,
            "osVersion": UIDevice.current.systemVersion,
            "appVersion": Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "",
            "buildVersion": Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? ""
        ]
        #else
        let data: [String: Any] = [
            "platform": "Unknown",
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString
        ]
        #endif

        return WaterBridgeResponse.success(data: data).value
    }
}
