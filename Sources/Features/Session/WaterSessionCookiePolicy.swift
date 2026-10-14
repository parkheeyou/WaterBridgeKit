#if canImport(WebKit)
import Foundation

public enum WaterSessionConflictPolicy: Sendable {
    case preferWeb
    case preferNative
}

public enum WaterSessionError: LocalizedError {
    case invalidScope
    case cookieOutsideScope

    public var errorDescription: String? {
        switch self {
        case .invalidScope: "세션 공유에는 유효한 도메인과 하나 이상의 쿠키 이름이 필요합니다."
        case .cookieOutsideScope: "설정한 세션 공유 범위 밖의 쿠키입니다."
        }
    }
}

struct WaterSessionCookieScope {
    let domains: Set<String>
    let names: Set<String>

    init(domains: Set<String>, names: Set<String>) throws {
        let normalized = Set(domains.map { Self.normalizeDomain($0) })
        guard !normalized.isEmpty, !names.isEmpty,
              names.allSatisfy({ !$0.isEmpty && !$0.contains(where: { $0.isWhitespace }) }),
              normalized.allSatisfy({ domain in
                  !domain.isEmpty && !domain.hasSuffix(".") &&
                  domain.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
                      !label.isEmpty && !label.hasPrefix("-") && !label.hasSuffix("-") &&
                      label.utf8.allSatisfy { (48...57).contains($0) || (97...122).contains($0) || $0 == 45 }
                  }
              }) else { throw WaterSessionError.invalidScope }
        self.domains = normalized
        self.names = names
    }

    func contains(_ cookie: HTTPCookie) -> Bool {
        let domain = Self.normalizeDomain(cookie.domain)
        return names.contains(cookie.name) && domains.contains { allowed in
            domain == allowed || domain.hasSuffix("." + allowed)
        }
    }

    static func normalizeDomain(_ domain: String) -> String {
        var result = domain.lowercased()
        while result.hasPrefix(".") { result.removeFirst() }
        return result
    }
}

struct WaterSessionCookieKey: Hashable {
    let name: String
    let domain: String
    let path: String

    init(_ cookie: HTTPCookie) {
        name = cookie.name
        domain = WaterSessionCookieScope.normalizeDomain(cookie.domain)
        path = cookie.path
    }
}

struct WaterSessionCookieSnapshot {
    let cookies: [WaterSessionCookieKey: HTTPCookie]

    init(_ cookies: [HTTPCookie], scope: WaterSessionCookieScope, now: Date = Date()) {
        self.cookies = cookies.reduce(into: [:]) { result, cookie in
            guard scope.contains(cookie), cookie.expiresDate.map({ $0 > now }) ?? true else { return }
            result[WaterSessionCookieKey(cookie)] = cookie
        }
    }

    static func equivalent(_ lhs: HTTPCookie?, _ rhs: HTTPCookie?) -> Bool {
        guard let lhs, let rhs else { return lhs == nil && rhs == nil }
        // WebKit은 만료 시각을 초 단위로 정규화할 수 있습니다.
        return lhs.value == rhs.value && lhs.isSecure == rhs.isSecure &&
            lhs.isHTTPOnly == rhs.isHTTPOnly &&
            lhs.expiresDate.map { Int64($0.timeIntervalSince1970) } == rhs.expiresDate.map { Int64($0.timeIntervalSince1970) } &&
            String(describing: lhs.properties?[HTTPCookiePropertyKey("SameSite")]) ==
            String(describing: rhs.properties?[HTTPCookiePropertyKey("SameSite")])
    }

    /// 변경된 쪽을 채택합니다. 양쪽이 동시에 바뀐 경우에만 우선순위를 적용합니다.
    static func merged(
        native: Self, web: Self, previous: [WaterSessionCookieKey: HTTPCookie],
        preference: WaterSessionConflictPolicy
    ) -> [WaterSessionCookieKey: HTTPCookie] {
        let keys = Set(native.cookies.keys).union(web.cookies.keys).union(previous.keys)
        return keys.reduce(into: [:]) { result, key in
            let appCookie = native.cookies[key]
            let webCookie = web.cookies[key]
            let nativeChanged = !equivalent(appCookie, previous[key])
            let webChanged = !equivalent(webCookie, previous[key])
            let selected: HTTPCookie?
            if nativeChanged && webChanged {
                selected = preference == .preferWeb ? webCookie : appCookie
            } else if nativeChanged {
                selected = appCookie
            } else if webChanged {
                selected = webCookie
            } else {
                selected = previous[key]
            }
            // nil도 변경 결과입니다. 삭제된 쿠키를 반대쪽에서 되살리지 않습니다.
            result[key] = selected
        }
    }
}
#endif
