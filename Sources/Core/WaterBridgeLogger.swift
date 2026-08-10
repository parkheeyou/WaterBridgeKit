import Foundation
import OSLog

enum WaterBridgeLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "WaterBridgeKit",
        category: "WaterBridge"
    )

    static func webViewLoadRequested(url: URL) {
        logger.info(
            "[WEBVIEW][REQUESTED] url=\(url.absoluteString, privacy: .public)"
        )
    }

    static func webViewNavigationStarted(url: URL?) {
        logger.info(
            "[WEBVIEW][STARTED] url=\(url?.absoluteString ?? "unknown", privacy: .public)"
        )
    }

    static func webViewContentCommitted(url: URL?) {
        logger.info(
            "[WEBVIEW][COMMITTED] url=\(url?.absoluteString ?? "unknown", privacy: .public)"
        )
    }

    static func webViewLoadFinished(url: URL?, elapsedTime: TimeInterval?) {
        logger.info(
            "[WEBVIEW][FINISHED] url=\(url?.absoluteString ?? "unknown", privacy: .public) elapsed=\(formatted(elapsedTime), privacy: .public)s"
        )
    }

    static func webViewLoadFailed(
        url: URL?,
        error: Error,
        elapsedTime: TimeInterval?
    ) {
        let nsError = error as NSError
        logger.error(
            "[WEBVIEW][FAILED] url=\(url?.absoluteString ?? "unknown", privacy: .public) elapsed=\(formatted(elapsedTime), privacy: .public)s domain=\(nsError.domain, privacy: .public) code=\(nsError.code) message=\(nsError.localizedDescription, privacy: .public)"
        )
    }

    static func webViewLoadCancelled(url: URL?) {
        logger.info(
            "[WEBVIEW][CANCELLED] url=\(url?.absoluteString ?? "unknown", privacy: .public)"
        )
    }

    static func received(_ message: WaterBridgeMessage) {
        logger.info(
            "[RECEIVED] api=\(message.api ?? "unknown", privacy: .public) source=\(message.sourceURL?.absoluteString ?? "unknown", privacy: .public) request=\(description(of: message.body), privacy: .public)"
        )
    }

    static func responded(api: String, response: Any) {
        logger.info(
            "[RESPONDED] api=\(api, privacy: .public) response=\(description(of: response), privacy: .public)"
        )
    }

    static func rejected(reason: String, body: Any) {
        logger.error(
            "[REJECTED] reason=\(reason, privacy: .public) request=\(description(of: body), privacy: .public)"
        )
    }

    private static func description(of value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.sortedKeys, .fragmentsAllowed]
              ),
              let json = String(data: data, encoding: .utf8) else {
            return String(describing: value)
        }

        return json
    }

    private static func formatted(_ elapsedTime: TimeInterval?) -> String {
        guard let elapsedTime else { return "unknown" }
        return String(format: "%.3f", elapsedTime)
    }
}
