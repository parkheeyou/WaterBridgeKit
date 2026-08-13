import Foundation
import WaterBridgeCore

/// WebView가 사용할 브릿지 채널과 앱 전용 Route를 설정합니다.
public struct WaterBridgeConfiguration {
    public static let defaultChannel = "Bridge"

    public let channel: String
    public let additionalRoutes: [WaterBridgeRoute]

    public init(
        channel: String = Self.defaultChannel,
        additionalRoutes: [WaterBridgeRoute] = []
    ) {
        let channel = channel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.channel = channel.isEmpty ? Self.defaultChannel : channel
        self.additionalRoutes = additionalRoutes
    }
}
