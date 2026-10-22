import Foundation

/// JavaScript에서 네이티브로 전달한 브릿지 메시지입니다.
public struct WaterBridgeMessage {
    /// 이 메시지의 API 이름을 해석할 URL 스킴입니다. 기본값은 `water`입니다.
    public let scheme: String

    /// 등록된 WebKit 메시지 핸들러 이름입니다. 기본값은 `Bridge`입니다.
    public let channel: String

    /// JavaScript의 `postMessage`에 전달된 원본 값입니다.
    public let body: Any

    /// 메시지를 보낸 메인 문서의 URL입니다.
    public let sourceURL: URL?

    public init(channel: String, body: Any, sourceURL: URL?, scheme: String = "water") {
        self.scheme = WaterBridgeScheme.normalized(scheme)
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

    /// 쿼리 파라미터를 제외한 브릿지 API 주소입니다.
    public var api: String? {
        guard let value = apiValue else { return nil }
        return value.components(separatedBy: CharacterSet(charactersIn: "?#")).first
    }

    /// 브릿지 URI의 쿼리입니다. 값은 URLComponents가 한 번만 디코딩합니다.
    public var queryItems: [URLQueryItem] {
        guard let value = apiValue else { return [] }
        return URLComponents(string: value)?.queryItems ?? []
    }

    private var rawCommand: String? {
        guard let value = body as? String, hasSchemePrefix(value),
              let command = value.components(separatedBy: "?").first,
              !(command.removingPercentEncoding ?? command).contains("{") else { return nil }
        return scheme + "://" + value.dropFirst(scheme.count + 3)
    }

    private func hasSchemePrefix(_ value: String) -> Bool {
        value.lowercased().hasPrefix(scheme + "://")
    }

    private var apiValue: String? {
        func normalized(_ value: Any?) -> String? {
            guard let value = value as? String, !value.isEmpty else { return nil }
            if let separator = value.range(of: "://") {
                return value[..<separator.lowerBound].lowercased() + value[separator.lowerBound...]
            }
            return "\(scheme)://\(value)"
        }
        if let rawCommand { return rawCommand }
        if let dictionary {
            return normalized(dictionary["api"]) ?? normalized(dictionary["method"])
                ?? normalized(dictionary["name"]) ?? normalized(dictionary["action"])
        }
        guard let value = body as? String, !value.contains("{") else { return nil }
        return normalized(value)
    }

    private var dictionary: [String: Any]? {
        // 이동 URL의 JSON 쿼리 등을 브릿지 envelope로 오인하지 않습니다.
        if rawCommand != nil { return nil }
        if let dictionary = body as? [String: Any] {
            return expandingNestedEnvelope(in: dictionary)
        }

        guard let value = body as? String else { return nil }
        return decodeEnvelope(value)
    }

    private func value(for key: String) -> Any? {
        guard let value = dictionary?[key], !(value is NSNull) else {
            return nil
        }
        return value
    }

    private func decodeEnvelope(_ value: String) -> [String: Any]? {
        let decodedValues = [
            value.removingPercentEncoding,
            value
        ].compactMap { $0 }

        for decodedValue in decodedValues {
            let trimmedValue = decodedValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if trimmedValue.contains("://"), !trimmedValue.hasPrefix("{"), !hasSchemePrefix(trimmedValue) { continue }
            var candidates = [trimmedValue]

            if hasSchemePrefix(trimmedValue) {
                candidates.append(String(trimmedValue.dropFirst(scheme.count + 3)))
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

    private func expandingNestedEnvelope(
        in dictionary: [String: Any]
    ) -> [String: Any] {
        if let api = dictionary["api"] as? String, hasSchemePrefix(api),
           let command = api.components(separatedBy: "?").first, !(command.removingPercentEncoding ?? command).contains("{") {
            return dictionary
        }
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
