import Foundation

/// JavaScript에서 네이티브로 전달한 브릿지 메시지입니다.
public struct WaterBridgeMessage {
    /// 등록된 WebKit 메시지 핸들러 이름입니다. 기본값은 `Bridge`입니다.
    public let channel: String

    /// JavaScript의 `postMessage`에 전달된 원본 값입니다.
    public let body: Any

    /// 메시지를 보낸 메인 문서의 URL입니다.
    public let sourceURL: URL?

    public init(channel: String, body: Any, sourceURL: URL?) {
        self.channel = channel
        self.body = body
        self.sourceURL = sourceURL
    }

    /// `{ action: "..." }` 형태로 전달했을 때의 액션 이름입니다.
    public var action: String? {
        dictionary?["action"] as? String
    }

    /// 브릿지 호출과 함께 전달된 `data`입니다.
    public var data: Any? {
        value(for: "data")
    }

    /// 웹에서 응답을 받을 JavaScript callback 함수 이름입니다.
    public var callback: String? {
        guard let callback = dictionary?["callback"] as? String else {
            return nil
        }

        let value = callback.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// 기존 `{ payload: ... }`, `{ params: ... }` 호출과의 호환용 값입니다.
    /// 새 envelope의 `data`도 같은 방식으로 조회할 수 있습니다.
    public var payload: Any? {
        data ?? value(for: "payload") ?? value(for: "params")
    }

    /// `water://...` 형식으로 전달된 브릿지 API입니다.
    public var api: String? {
        func normalizedAPI(_ value: Any?) -> String? {
            guard let value = value as? String, !value.isEmpty else { return nil }
            return value.hasPrefix("water://") ? value : "water://\(value)"
        }

        if let dictionary {
            return normalizedAPI(dictionary["api"])
                ?? normalizedAPI(dictionary["method"])
                ?? normalizedAPI(dictionary["name"])
                ?? normalizedAPI(dictionary["action"])
        }

        guard let value = body as? String,
              !value.contains("{") else {
            return nil
        }
        return normalizedAPI(value)
    }

    private var dictionary: [String: Any]? {
        if let dictionary = body as? [String: Any] {
            return Self.expandingNestedEnvelope(in: dictionary)
        }

        guard let value = body as? String else { return nil }
        return Self.decodeEnvelope(value)
    }

    private func value(for key: String) -> Any? {
        guard let value = dictionary?[key], !(value is NSNull) else {
            return nil
        }
        return value
    }

    private static func decodeEnvelope(_ value: String) -> [String: Any]? {
        let decodedValues = [
            value.removingPercentEncoding,
            value
        ].compactMap { $0 }

        for decodedValue in decodedValues {
            let trimmedValue = decodedValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            var candidates = [trimmedValue]

            if trimmedValue.hasPrefix("water://") {
                candidates.append(String(trimmedValue.dropFirst("water://".count)))
            }

            if let openingBrace = trimmedValue.firstIndex(of: "{"),
               let closingBrace = trimmedValue.lastIndex(of: "}"),
               openingBrace <= closingBrace {
                candidates.append(
                    String(trimmedValue[openingBrace...closingBrace])
                )
            }

            for candidate in candidates {
                guard let data = candidate.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data),
                      let dictionary = object as? [String: Any] else {
                    continue
                }
                return expandingNestedEnvelope(in: dictionary)
            }
        }

        return nil
    }

    private static func expandingNestedEnvelope(
        in dictionary: [String: Any]
    ) -> [String: Any] {
        guard let api = dictionary["api"] as? String,
              let nestedDictionary = decodeEnvelope(api) else {
            return dictionary
        }

        return dictionary.merging(nestedDictionary) { _, nestedValue in
            nestedValue
        }
    }
}

/// 메인 액터에서 JavaScript 브릿지 메시지를 처리하는 콜백입니다.
public typealias WaterBridgeMessageHandler = @MainActor (WaterBridgeMessage) -> Void
