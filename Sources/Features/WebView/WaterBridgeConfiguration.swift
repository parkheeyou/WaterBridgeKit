import Foundation
import WaterBridgeCore

/// WebView가 사용할 브릿지 채널과 앱 전용 Route를 설정합니다.
public struct WaterBridgeConfiguration {
    public static let defaultChannel = "Bridge"

    public let scheme: String
    public let channel: String
    public let additionalRoutes: [WaterBridgeRoute]
    /// DEBUG 빌드에서만 웹 console 및 처리되지 않은 JavaScript 오류를 수집합니다.
    public let capturesWebConsoleLogs: Bool
    public let showsDebugConsole: Bool
    public let sessionSynchronizer: WaterSessionSynchronizer?

    public init(
        channel: String = Self.defaultChannel,
        scheme: String = "water",
        additionalRoutes: [WaterBridgeRoute] = [],
        showsDebugConsole: Bool = true,
        capturesWebConsoleLogs: Bool = true,
        sessionSynchronizer: WaterSessionSynchronizer? = nil
    ) {
        let channel = channel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scheme = WaterBridgeScheme.normalized(scheme)
        self.channel = channel.isEmpty ? Self.defaultChannel : channel
        self.additionalRoutes = additionalRoutes
        self.capturesWebConsoleLogs = capturesWebConsoleLogs
        self.showsDebugConsole = showsDebugConsole
        self.sessionSynchronizer = sessionSynchronizer
    }
}
