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
            api: WaterBridgeRouteAPIListHandler.shared.api,
            version: 2,
            handler: WaterBridgeRouteAPIListHandler.shared.handle
        ),
        (
            api: WaterBridgeNativeInfoHandler.shared.api,
            version: 2,
            handler: WaterBridgeNativeInfoHandler.shared.handle
        ),
        (
            api: WaterBridgeExitHandler.shared.api,
            version: 1,
            handler: WaterBridgeExitHandler.shared.handle
        ),
        (api: WaterBridgeAlertHandler.shared.api, version: 1, handler: WaterBridgeAlertHandler.shared.handle),
        (api: WaterBridgeOpenURLHandler.safariAPI, version: 1, handler: WaterBridgeOpenURLHandler.safari),
        (api: WaterBridgeOpenURLHandler.webViewAPI, version: 1, handler: WaterBridgeOpenURLHandler.webView)
    ]
}
