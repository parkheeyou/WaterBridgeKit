#if canImport(WebKit)
import Foundation
import WebKit
import XCTest
@testable import WaterBridgeKit

final class WaterSessionSynchronizerTests: XCTestCase {
    private func cookie(_ value: String, domain: String = ".example.com", name: String = "session", path: String = "/", expires: Date? = nil) throws -> HTTPCookie {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain, .name: name, .path: path, .value: value,
            .secure: "TRUE", HTTPCookiePropertyKey("HttpOnly"): "TRUE"
        ]
        if let expires { properties[.expires] = expires }
        return try XCTUnwrap(HTTPCookie(properties: properties))
    }

    func testScopeRejectsLookalikeDomainsAndUnlistedNames() throws {
        let scope = try WaterSessionCookieScope(domains: ["example.com"], names: ["session"])
        XCTAssertTrue(scope.contains(try cookie("a")))
        XCTAssertTrue(scope.contains(try cookie("a", domain: "api.example.com")))
        XCTAssertFalse(scope.contains(try cookie("a", domain: "evil-example.com")))
        XCTAssertFalse(scope.contains(try cookie("a", domain: "example.com.evil.test")))
        XCTAssertFalse(scope.contains(try cookie("a", name: "analytics")))
        XCTAssertThrowsError(try WaterSessionCookieScope(domains: [], names: ["session"]))
        XCTAssertThrowsError(try WaterSessionCookieScope(domains: ["https://example.com"], names: ["session"]))
        XCTAssertThrowsError(try WaterSessionCookieScope(domains: ["example.com"], names: []))
    }

    func testDeletedCookieDoesNotResurrectFromUnchangedPeer() throws {
        let scope = try WaterSessionCookieScope(domains: ["example.com"], names: ["session"])
        let original = try cookie("old")
        let stored = WaterSessionCookieSnapshot([original], scope: scope)
        let empty = WaterSessionCookieSnapshot([], scope: scope)
        XCTAssertTrue(WaterSessionCookieSnapshot.merged(native: stored, web: empty, previous: stored.cookies, preference: .preferNative).isEmpty)
        XCTAssertTrue(WaterSessionCookieSnapshot.merged(native: empty, web: stored, previous: stored.cookies, preference: .preferWeb).isEmpty)
    }

    func testConflictingRotationsUseRequestedSourceAndKeepDistinctPaths() throws {
        let scope = try WaterSessionCookieScope(domains: ["example.com"], names: ["session"])
        let original = try cookie("old")
        let native = WaterSessionCookieSnapshot([try cookie("native"), try cookie("other-path", path: "/api")], scope: scope)
        let web = WaterSessionCookieSnapshot([try cookie("web")], scope: scope)
        let key = WaterSessionCookieKey(original)
        let preferWeb = WaterSessionCookieSnapshot.merged(native: native, web: web, previous: [key: original], preference: .preferWeb)
        let preferNative = WaterSessionCookieSnapshot.merged(native: native, web: web, previous: [key: original], preference: .preferNative)
        XCTAssertEqual(preferWeb[key]?.value, "web")
        XCTAssertEqual(preferNative[key]?.value, "native")
        XCTAssertEqual(preferWeb.count, 2)
    }

    func testExpiredCookiesAreExcluded() throws {
        let scope = try WaterSessionCookieScope(domains: ["example.com"], names: ["session"])
        let snapshot = WaterSessionCookieSnapshot([try cookie("expired", expires: Date(timeIntervalSince1970: 1))], scope: scope)
        XCTAssertTrue(snapshot.cookies.isEmpty)
    }

    @MainActor
    func testNativeLoginReachesWebAndWebRotationReachesNative() async throws {
        let store = WKWebsiteDataStore.nonPersistent()
        let sync = try WaterSessionSynchronizer(allowedDomains: ["example.com"], cookieNames: ["session"], websiteDataStore: store)
        try await sync.setCookiesFromNative([cookie("native")])
        let first = await store.httpCookieStore.allCookies()
        XCTAssertEqual(first.first(where: { $0.name == "session" })?.value, "native")
        XCTAssertEqual(first.first(where: { $0.name == "session" })?.isSecure, true)
        XCTAssertEqual(first.first(where: { $0.name == "session" })?.isHTTPOnly, true)
        await store.httpCookieStore.setCookie(try cookie("web"))
        await sync.synchronizeFromWeb()
        XCTAssertEqual(sync.nativeStorage.cookies?.first(where: { $0.name == "session" })?.value, "web")
        // 앱 우선 동기화를 다시 수행해도 이미 반영된 웹의 쿠키 회전을 되돌리지 않습니다.
        await sync.synchronizeFromNative()
        let second = await store.httpCookieStore.allCookies()
        XCTAssertEqual(second.first(where: { $0.name == "session" })?.value, "web")
        let counts = await sync.cookieCounts()
        XCTAssertEqual(counts.native, 1)
        XCTAssertEqual(counts.web, 1)
        await sync.clearSession()
    }

    @MainActor
    func testWebDeletionIsPropagatedAndLogoutPreservesUnrelatedCookies() async throws {
        let store = WKWebsiteDataStore.nonPersistent()
        let sync = try WaterSessionSynchronizer(allowedDomains: ["example.com"], cookieNames: ["session"], websiteDataStore: store)
        let sessionCookie = try cookie("login")
        let unrelated = try cookie("keep", name: "analytics")
        let foreign = try cookie("keep-foreign", domain: "other.test")
        await store.httpCookieStore.setCookie(unrelated)
        await store.httpCookieStore.setCookie(foreign)
        try await sync.setCookiesFromNative([sessionCookie])
        await store.httpCookieStore.deleteCookie(sessionCookie)
        await sync.synchronizeFromWeb()
        await sync.synchronizeFromNative()
        let afterDelete = await sync.cookieCounts()
        XCTAssertEqual(afterDelete.native, 0)
        XCTAssertEqual(afterDelete.web, 0)
        try await sync.setCookiesFromNative([sessionCookie])
        await sync.clearSession()
        await sync.synchronizeFromNative()
        let remaining = await store.httpCookieStore.allCookies()
        XCTAssertEqual(Set(remaining.map(\.name)), ["analytics", "session"])
        XCTAssertFalse(remaining.contains { $0.name == "session" && $0.domain.contains("example.com") })
        let afterLogout = await sync.cookieCounts()
        XCTAssertEqual(afterLogout.native, 0)
        XCTAssertEqual(afterLogout.web, 0)
    }

    @MainActor
    func testRealWebLoginAndNativeLoginShareHttpOnlySession() async throws {
        let server = try SessionHTTPFixture()
        let baseURL = try await server.start()
        defer { server.stop() }
        let store = WKWebsiteDataStore.nonPersistent()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = store
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let navigation = SessionWebNavigation()
        let sync = try WaterSessionSynchronizer(allowedDomains: ["127.0.0.1"], cookieNames: ["session"], websiteDataStore: store)
        XCTAssertTrue(sync.responds(to: #selector(WKHTTPCookieStoreObserver.cookiesDidChange(in:))))
        await sync.start()
        try await navigation.load(baseURL.appendingPathComponent("web-login"), in: webView)
        for _ in 0..<100 {
            if sync.nativeStorage.cookies?.contains(where: { $0.value == "web" }) == true { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        // 명시적 동기화를 수행하기 전에 observer가 반영했는지 확인합니다.
        XCTAssertEqual(sync.nativeStorage.cookies?.first(where: { $0.name == "session" })?.value, "web")
        let transport = sync.makeTransport()
        let (nativeBody, _) = try await transport.data(for: URLRequest(url: baseURL.appendingPathComponent("whoami")))
        XCTAssertTrue(String(decoding: nativeBody, as: UTF8.self).contains("session=web"))
        _ = try await transport.data(for: URLRequest(url: baseURL.appendingPathComponent("native-login")))
        let webCookies = await store.httpCookieStore.allCookies()
        XCTAssertEqual(webCookies.first(where: { $0.name == "session" })?.value, "native")
        XCTAssertEqual(webCookies.first(where: { $0.name == "session" })?.isHTTPOnly, true)
        try await navigation.load(baseURL.appendingPathComponent("whoami"), in: webView)
        let webBody = try await webView.evaluateJavaScript("document.body.textContent") as? String
        XCTAssertTrue(webBody?.contains("session=native") == true)
        _ = try await transport.data(for: URLRequest(url: baseURL.appendingPathComponent("logout")))
        let afterLogout = await sync.cookieCounts()
        XCTAssertEqual(afterLogout.native, 0)
        XCTAssertEqual(afterLogout.web, 0)
        webView.stopLoading()
        await sync.stopObserving()
        await sync.clearSession()
    }

    @MainActor
    func testNativeExpiredCookieDeletesWebSession() async throws {
        let store = WKWebsiteDataStore.nonPersistent()
        let sync = try WaterSessionSynchronizer(allowedDomains: ["example.com"], cookieNames: ["session"], websiteDataStore: store)
        try await sync.setCookiesFromNative([cookie("login")])
        try await sync.setCookiesFromNative([cookie("expired", expires: Date(timeIntervalSince1970: 1))])
        let remaining = await store.httpCookieStore.allCookies()
        XCTAssertFalse(remaining.contains { $0.name == "session" })
        XCTAssertFalse(sync.nativeStorage.cookies?.contains(where: { $0.name == "session" }) ?? false)
        await sync.stopObserving()
    }

    @MainActor
    func testInitialConflictPolicyAndOutsideScopeBatchValidation() async throws {
        for preference in [WaterSessionConflictPolicy.preferWeb, .preferNative] {
            let store = WKWebsiteDataStore.nonPersistent()
            await store.httpCookieStore.setCookie(try cookie("web"))
            let sync = try WaterSessionSynchronizer(allowedDomains: ["example.com"], cookieNames: ["session"], websiteDataStore: store, initialCookies: [cookie("native")], initialConflictPolicy: preference)
            await sync.start()
            let cookies = await store.httpCookieStore.allCookies()
            XCTAssertEqual(cookies.first?.value, preference == .preferWeb ? "web" : "native")
            do {
                try await sync.setCookiesFromNative([cookie("replace"), cookie("outside", domain: "other.test")])
                XCTFail("Expected scope rejection")
            } catch WaterSessionError.cookieOutsideScope { }
            let after = await store.httpCookieStore.allCookies()
            XCTAssertEqual(after.first?.value, cookies.first?.value)
            await sync.clearSession()
        }
    }
}
#endif
