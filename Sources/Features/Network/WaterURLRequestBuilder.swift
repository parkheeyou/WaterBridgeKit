import Foundation

package enum WaterURLRequestBuilder {
    package static func makeRequest<API: WaterAPIEndpoint>(
        endpoint: API,
        requestData: WaterAPIRequest,
        configuration: WaterNetworkConfiguration
    ) throws -> URLRequest {
        let url = try makeURL(
            baseURL: configuration.baseURL,
            path: endpoint.path
        )
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = configuration.timeoutInterval

        configuration.headers.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        configuration.headerProvider().forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        endpoint.headers?.forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        do {
            try apply(
                requestData,
                to: &request,
                encoder: configuration.encoderFactory()
            )
        } catch let error as WaterNetworkError {
            throw error
        } catch {
            throw WaterNetworkError.requestEncoding(
                message: error.localizedDescription
            )
        }

        return request
    }

    private static func makeURL(baseURL: URL, path: String) throws -> URL {
        if let absoluteURL = URL(string: path),
           let scheme = absoluteURL.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return absoluteURL
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.isEmpty {
            return baseURL
        }

        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relative = trimmedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/\(relative)") else {
            throw WaterNetworkError.invalidURL(path: path)
        }
        return url
    }

    private static func apply(
        _ requestData: WaterAPIRequest,
        to request: inout URLRequest,
        encoder: JSONEncoder
    ) throws {
        switch requestData {
        case .plain:
            break

        case let .query(items):
            request.url = try adding(items, to: request.url)

        case let .queryEncodable(value):
            let items = try queryItems(from: value, encoder: encoder)
            request.url = try adding(items, to: request.url)

        case let .json(value):
            request.httpBody = try encoder.encode(value)
            setContentType("application/json", on: &request)

        case let .form(items):
            var components = URLComponents()
            components.queryItems = items.map {
                URLQueryItem(name: $0.name, value: $0.value)
            }
            request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
            setContentType("application/x-www-form-urlencoded", on: &request)

        case let .raw(data, contentType):
            request.httpBody = data
            if let contentType {
                setContentType(contentType, on: &request)
            }
        }
    }

    private static func adding(
        _ items: [WaterQueryItem],
        to url: URL?
    ) throws -> URL {
        guard let url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw WaterNetworkError.invalidURL(path: url?.absoluteString ?? "unknown")
        }

        components.queryItems = (components.queryItems ?? []) + items.map {
            URLQueryItem(name: $0.name, value: $0.value)
        }
        guard let result = components.url else {
            throw WaterNetworkError.invalidURL(path: url.absoluteString)
        }
        return result
    }

    private static func queryItems(
        from value: any Encodable,
        encoder: JSONEncoder
    ) throws -> [WaterQueryItem] {
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw WaterNetworkError.requestEncoding(
                message: "query 모델의 최상위 값은 객체여야 합니다."
            )
        }

        return try dictionary.keys.sorted().flatMap { key in
            try makeQueryItems(name: key, value: dictionary[key] as Any)
        }
    }

    private static func makeQueryItems(
        name: String,
        value: Any
    ) throws -> [WaterQueryItem] {
        if value is NSNull {
            return []
        }
        if let values = value as? [Any] {
            return try values.flatMap { try makeQueryItems(name: name, value: $0) }
        }
        if let value = value as? String {
            return [WaterQueryItem(name: name, value: value)]
        }
        if let value = value as? Bool {
            return [WaterQueryItem(name: name, value: value ? "true" : "false")]
        }
        if let value = value as? NSNumber {
            return [WaterQueryItem(name: name, value: value.stringValue)]
        }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value),
           let string = String(data: data, encoding: .utf8) {
            return [WaterQueryItem(name: name, value: string)]
        }

        throw WaterNetworkError.requestEncoding(
            message: "query 값으로 변환할 수 없습니다: \(name)"
        )
    }

    private static func setContentType(
        _ contentType: String,
        on request: inout URLRequest
    ) {
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
    }
}
