import Foundation
import OSLog

// 로그 찍기
package enum WaterBridgeLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "WaterBridgeKit",
        category: "WaterBridge"
    )

    package static func crashReporterEnabled() {
        logger.info("[CRASH][ENABLED]")
        capture("[ENABLED] 크래시 리포터가 시작되었습니다.", category: .crash)
    }

    package static func crashReporterSkippedForDebugger() {
        logger.info("[CRASH][SKIPPED] debugger is attached")
        capture("[SKIPPED] 디버거가 연결되어 크래시 리포터를 건너뜁니다.", category: .crash)
    }

    package static func crashReportRecovered(url: URL) {
        logger.error(
            "[CRASH][RECOVERED] log=\(url.path, privacy: .public)"
        )
        capture("[RECOVERED] log=\(url.path)", category: .crash, level: .error)
    }

    package static func webViewLoadRequested(url: URL) {
        logger.info(
            "[WEBVIEW][REQUESTED] url=\(url.absoluteString, privacy: .public)"
        )
        capture("[REQUESTED] url=\(url.absoluteString)", category: .webView)
    }

    package static func webViewNavigationStarted(url: URL?) {
        logger.info(
            "[WEBVIEW][STARTED] url=\(url?.absoluteString ?? "unknown", privacy: .public)"
        )
        capture("[STARTED] url=\(url?.absoluteString ?? "unknown")", category: .webView)
    }

    package static func webViewContentCommitted(url: URL?) {
        logger.info(
            "[WEBVIEW][COMMITTED] url=\(url?.absoluteString ?? "unknown", privacy: .public)"
        )
        capture("[COMMITTED] url=\(url?.absoluteString ?? "unknown")", category: .webView)
    }

    package static func webViewLoadFinished(url: URL?, elapsedTime: TimeInterval?) {
        logger.info(
            "[WEBVIEW][FINISHED] url=\(url?.absoluteString ?? "unknown", privacy: .public) elapsed=\(formatted(elapsedTime), privacy: .public)s"
        )
        capture(
            "[FINISHED] url=\(url?.absoluteString ?? "unknown") elapsed=\(formatted(elapsedTime))s",
            category: .webView
        )
    }

    package static func webViewLoadFailed(
        url: URL?,
        error: Error,
        elapsedTime: TimeInterval?
    ) {
        let nsError = error as NSError
        logger.error(
            "[WEBVIEW][FAILED] url=\(url?.absoluteString ?? "unknown", privacy: .public) elapsed=\(formatted(elapsedTime), privacy: .public)s domain=\(nsError.domain, privacy: .public) code=\(nsError.code) message=\(nsError.localizedDescription, privacy: .public)"
        )
        capture(
            "[FAILED] url=\(url?.absoluteString ?? "unknown") elapsed=\(formatted(elapsedTime))s domain=\(nsError.domain) code=\(nsError.code) message=\(nsError.localizedDescription)",
            category: .webView,
            level: .error
        )
    }

    package static func webViewLoadCancelled(url: URL?) {
        logger.info(
            "[WEBVIEW][CANCELLED] url=\(url?.absoluteString ?? "unknown", privacy: .public)"
        )
        capture("[CANCELLED] url=\(url?.absoluteString ?? "unknown")", category: .webView)
    }

    package static func received(_ message: WaterBridgeMessage) {
        logger.info(
            "[RECEIVED] api=\(message.api ?? "unknown", privacy: .public) source=\(message.sourceURL?.absoluteString ?? "unknown", privacy: .public) request=\(description(of: message.body), privacy: .public)"
        )
        capture(
            "[RECEIVED] api=\(message.api ?? "unknown") source=\(message.sourceURL?.absoluteString ?? "unknown") request=\(description(of: message.body))",
            category: .bridge
        )
    }

    package static func responded(api: String, response: Any) {
        logger.info(
            "[RESPONDED] api=\(api, privacy: .public) response=\(description(of: response), privacy: .public)"
        )
        capture(
            "[RESPONDED] api=\(api) response=\(description(of: response))",
            category: .bridge
        )
    }

    package static func callbackCompleted(api: String, callback: String) {
        logger.info(
            "[CALLBACK][COMPLETED] api=\(api, privacy: .public) callback=\(callback, privacy: .public)"
        )
        capture(
            "[CALLBACK][COMPLETED] api=\(api) callback=\(callback)",
            category: .bridge
        )
    }

    package static func callbackFailed(
        api: String,
        callback: String,
        error: Error
    ) {
        logger.error(
            "[CALLBACK][FAILED] api=\(api, privacy: .public) callback=\(callback, privacy: .public) message=\(error.localizedDescription, privacy: .public)"
        )
        capture(
            "[CALLBACK][FAILED] api=\(api) callback=\(callback) message=\(error.localizedDescription)",
            category: .bridge,
            level: .error
        )
    }

    package static func rejected(reason: String, body: Any) {
        logger.error(
            "[REJECTED] reason=\(reason, privacy: .public) request=\(description(of: body), privacy: .public)"
        )
        capture(
            "[REJECTED] reason=\(reason) request=\(description(of: body))",
            category: .bridge,
            level: .error
        )
    }

    private static func capture(
        _ message: String,
        category: WaterDebugLogCategory,
        level: WaterDebugLogLevel = .info
    ) {
        WaterDebugLogger.capture(message, category: category, level: level)
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
