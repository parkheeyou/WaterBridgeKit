import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum WaterBridgeRouter {
    /// 새로운 브릿지 API는 이 목록에 `WaterBridgeRoute`를 추가해 등록합니다.
    private static var registeredRoutes: [WaterBridgeRoute] {
        [
            WaterBridgeRoute(
                api: "water://routeApiList",
                version: 2,
                handler: routeAPIList
            ),
            WaterBridgeRoute(
                api: "water://nativeInfo",
                version: 2,
                handler: nativeInfo
            )
        ]
    }

    static func response(for message: WaterBridgeMessage) -> Any {
        guard let api = message.api else {
            return WaterBridgeResponse
                .failure(message: "브릿지 API가 없습니다.")
                .value
        }

        guard let route = registeredRoutes.first(where: { $0.api == api }) else {
            return WaterBridgeResponse
                .failure(message: "지원하지 않는 API입니다: \(api)")
                .value
        }

        return route.handle(message)
    }

    private static func routeAPIList(_ message: WaterBridgeMessage) -> Any {
        WaterBridgeResponse.success(
            data: registeredRoutes.map(\.descriptor)
        ).value
    }

    private static func nativeInfo(_ message: WaterBridgeMessage) -> Any {
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
