import Foundation
import WaterBridgeCore

#if canImport(UIKit)
import UIKit
#endif

/// 앱과 기기의 기본 네이티브 정보를 반환합니다.
@MainActor
enum WaterBridgeNativeInfoHandler {
    static func handle(_ message: WaterBridgeMessage) -> Any {
        let versionName = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? ""
        let buildVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "0"

        #if canImport(UIKit)
        let data: [String: Any] = [
            "platform": UIDevice.current.systemName,
            "osVersion": "\(UIDevice.current.systemName) \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "appVersion": [
                "versionCode": Int(buildVersion) ?? 0,
                "versionName": versionName
            ],
            "deviceInfo": [
                "modelNumber": modelNumber
            ]
        ]
        #else
        let data: [String: Any] = [
            "platform": "Unknown",
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "appVersion": [
                "versionCode": Int(buildVersion) ?? 0,
                "versionName": versionName
            ],
            "deviceInfo": [
                "modelNumber": ProcessInfo.processInfo.hostName
            ]
        ]
        #endif

        return WaterBridgeResponse.success(data: data).value
    }

    #if canImport(UIKit)
    private static var modelNumber: String {
        if let simulatorModel = ProcessInfo.processInfo.environment[
            "SIMULATOR_MODEL_IDENTIFIER"
        ], !simulatorModel.isEmpty {
            return simulatorModel
        }

        var systemInfo = utsname()
        uname(&systemInfo)

        let identifier = withUnsafeBytes(of: &systemInfo.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        return identifier.isEmpty ? UIDevice.current.model : identifier
    }
    #endif
}
