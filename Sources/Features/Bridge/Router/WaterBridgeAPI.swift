import WaterBridgeCore

/// WaterBridgeKit에서 제공하는 브릿지 API 정의 목록입니다.
///
/// 새로운 브릿지는 `all`에 API 이름, 버전, Handler를 추가하면
/// `WaterBridgeRouteRegistry`에 자동으로 등록됩니다.
@MainActor
enum WaterBridgeAPI {
    typealias Definition = (
        api: String,
        version: Int,
        handler: WaterBridgeRoute.Handler
    )

    static let all: [Definition] = [
        (
            api: "routeApiList",
            version: 2,
            handler: WaterBridgeRouteAPIListHandler.handle
        ),
        (
            api: "nativeInfo",
            version: 2,
            handler: WaterBridgeNativeInfoHandler.handle
        ),
        (
            api: WaterBridgeExitHandler.api,
            version: 1,
            handler: WaterBridgeExitHandler.handle
        ),
        (api: WaterBridgeAlertHandler.api, version: 1, handler: WaterBridgeAlertHandler.handle),
        (api: WaterBridgeOpenURLHandler.safariAPI, version: 1, handler: WaterBridgeOpenURLHandler.safari),
        (api: WaterBridgeOpenURLHandler.webViewAPI, version: 1, handler: WaterBridgeOpenURLHandler.webView)
    ]
}
