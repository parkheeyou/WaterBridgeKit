#if DEBUG && canImport(UIKit) && canImport(WebKit)
import WebKit
import WaterBridgeCore

/// 독립된 메시지 채널을 사용하므로 console 출력이 브릿지 API로 실행되지 않습니다.
@MainActor
final class WaterWebConsoleCapture: NSObject, WKScriptMessageHandler {
    let channel = "WaterConsole_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    private let record: @MainActor (String, WaterDebugLogLevel) -> Void

    init(record: @escaping @MainActor (String, WaterDebugLogLevel) -> Void = {
        WaterDebugLogger.log($0, category: .webView, level: $1)
    }) {
        self.record = record
    }

    func install(on controller: WKUserContentController) {
        controller.add(self, contentWorld: .page, name: channel)
        controller.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: false))
    }

    func remove(from controller: WKUserContentController) {
        controller.removeScriptMessageHandler(forName: channel, contentWorld: .page)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == channel,
              let body = message.body as? [String: Any],
              let kind = body["kind"] as? String,
              let text = body["text"] as? String else { return }
        let level: WaterDebugLogLevel
        switch kind {
        case "debug": level = .debug
        case "log", "info": level = .info
        case "warn": level = .warning
        case "error", "exception", "rejection": level = .error
        default: return
        }
        let frame = message.frameInfo.isMainFrame ? "main" : "iframe"
        record("[console.\(kind)][\(frame)] \(String(text.prefix(12_000)))", level)
    }

    var script: String {
        // channel은 내부에서 생성한 영숫자/밑줄 문자열입니다.
        #"""
        (() => {
            const handler = window.webkit.messageHandlers['\#(channel)'];
            if (!handler || typeof handler.postMessage !== 'function') return;
            const post = handler.postMessage.bind(handler);
            const limit = value => String(value).slice(0, 2000);
            function safe(value, seen, depth, budget) {
                if (budget.remaining-- <= 0) return '[Truncated]';
                if (value === null) return null;
                if (typeof value === 'string') return limit(value);
                if (typeof value === 'number' || typeof value === 'boolean') return value;
                if (typeof value !== 'object') return limit(value);
                if (seen.has(value)) return '[Circular]';
                if (depth >= 4) return '[MaxDepth]';
                seen.add(value);
                if (value instanceof Error) return limit(value.name + ': ' + value.message + '\n' + (value.stack || ''));
                if (value instanceof Node) return limit('<' + value.nodeName + '>');
                const result = Array.isArray(value) ? [] : Object.create(null);
                for (const key of Object.keys(value).slice(0, 30)) {
                    if (budget.remaining <= 0) break;
                    try {
                        const descriptor = Object.getOwnPropertyDescriptor(value, key);
                        result[key] = descriptor && 'value' in descriptor
                            ? safe(descriptor.value, seen, depth + 1, budget) : '[Getter]';
                    } catch (_) { result[key] = '[Unserializable]'; }
                }
                return result;
            }
            function forward(kind, args) {
                try {
                    const budget = {remaining: 200};
                    const text = Array.from(args).slice(0, 20).map(value => {
                        try {
                            if (typeof value === 'string') return limit(value);
                            const converted = safe(value, new WeakSet(), 0, budget);
                            return typeof converted === 'string' ? converted : JSON.stringify(converted);
                        } catch (_) { return '[Unserializable]'; }
                    }).join(' ').slice(0, 12000);
                    post({kind, text});
                } catch (_) {}
            }
            for (const kind of ['log', 'info', 'debug', 'warn', 'error']) {
                const original = console[kind];
                console[kind] = function(...args) {
                    try { return original.apply(console, args); }
                    finally { forward(kind, args); }
                };
            }
            window.addEventListener('error', event => {
                if (event instanceof ErrorEvent) {
                    forward('exception', [event.message, event.error, event.filename + ':' + event.lineno + ':' + event.colno]);
                }
            });
            window.addEventListener('unhandledrejection', event => forward('rejection', [event.reason]));
        })();
        """#
    }
}
#endif
