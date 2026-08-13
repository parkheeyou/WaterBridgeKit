import Foundation

/// `routeApiList` 응답에 사용되는 브릿지 API 정보입니다.
public struct WaterBridgeRouteDescriptor: Equatable, Sendable {
    public let api: String
    public let version: Int

    public init(api: String, version: Int) {
        self.api = api
        self.version = version
    }

    package var value: [String: Any] {
        [
            "api": api,
            "version": version
        ]
    }
}

/// 브릿지 Handler에 전달되는 현재 WebView의 라우팅 정보입니다.
public struct WaterBridgeRouteContext: Sendable {
    public let channel: String
    public let routes: [WaterBridgeRouteDescriptor]

    public init(
        channel: String,
        routes: [WaterBridgeRouteDescriptor]
    ) {
        self.channel = channel
        self.routes = routes
    }
}

/// WaterBridge가 처리할 수 있는 단일 네이티브 API 정의입니다.
public struct WaterBridgeRoute {
    public typealias Handler = @MainActor (
        WaterBridgeMessage,
        WaterBridgeRouteContext
    ) -> Any

    public let api: String
    public let version: Int
    package let handler: Handler

    /// 등록된 전체 Route 정보가 필요한 Handler를 생성합니다.
    public init(
        api: String,
        version: Int,
        handler: @escaping Handler
    ) {
        self.api = api
        self.version = version
        self.handler = handler
    }

    /// 앱에서 간단한 추가 브릿지를 등록할 때 사용하는 편의 생성자입니다.
    public init(
        api: String,
        version: Int,
        handler: @escaping @MainActor (WaterBridgeMessage) -> Any
    ) {
        self.init(api: api, version: version) { message, _ in
            handler(message)
        }
    }

    public var descriptor: WaterBridgeRouteDescriptor {
        WaterBridgeRouteDescriptor(api: api, version: version)
    }

    @MainActor
    package func handle(
        _ message: WaterBridgeMessage,
        context: WaterBridgeRouteContext
    ) -> Any {
        handler(message, context)
    }
}
