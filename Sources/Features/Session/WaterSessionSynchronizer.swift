#if canImport(WebKit)
import Foundation
import WebKit
import WaterBridgeCore

/// 한 로그인 서비스의 명시된 쿠키만 앱 URLSession과 WebKit 사이에서 동기화합니다.
/// 동일한 websiteDataStore/도메인/쿠키 범위에는 하나의 인스턴스를 사용하세요.
@MainActor
public final class WaterSessionSynchronizer: NSObject, @preconcurrency WKHTTPCookieStoreObserver {
    public let websiteDataStore: WKWebsiteDataStore
    // observer를 등록한 Objective-C 쿠키 저장소 래퍼의 수명을 유지합니다.
    private let webCookieStore: WKHTTPCookieStore
    private let scope: WaterSessionCookieScope
    private let initialConflictPolicy: WaterSessionConflictPolicy
    package private(set) var nativeStorage: HTTPCookieStorage
    private var nativeSession: URLSession
    private var previous: [WaterSessionCookieKey: HTTPCookie] = [:]
    private var hasStarted = false
    private var hasSynchronized = false
    private var pendingOperation: Task<Void, Never>?
    private var generation = 0

    public init(
        allowedDomains: Set<String>,
        cookieNames: Set<String>,
        websiteDataStore: WKWebsiteDataStore = .default(),
        initialCookies: [HTTPCookie] = [],
        initialConflictPolicy: WaterSessionConflictPolicy = .preferWeb
    ) throws {
        let scope = try WaterSessionCookieScope(domains: allowedDomains, names: cookieNames)
        guard initialCookies.allSatisfy(scope.contains) else { throw WaterSessionError.cookieOutsideScope }
        self.scope = scope
        self.websiteDataStore = websiteDataStore
        webCookieStore = websiteDataStore.httpCookieStore
        self.initialConflictPolicy = initialConflictPolicy
        // 공유 전역 저장소 대신 이 동기화 인스턴스 전용 네이티브 쿠키 저장소를 사용합니다.
        let configuration = URLSessionConfiguration.ephemeral
        nativeStorage = configuration.httpCookieStorage!
        for cookie in initialCookies where cookie.expiresDate.map({ $0 > Date() }) ?? true {
            nativeStorage.setCookie(cookie)
        }
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        nativeSession = URLSession(configuration: configuration)
        super.init()
    }

    deinit {
        nativeSession.invalidateAndCancel()
    }

    /// 자동 웹 쿠키 관찰을 중단합니다. 다음 start/동기화/요청 시 다시 시작합니다.
    public func stopObserving() async {
        await enqueue {
            self.webCookieStore.remove(self)
            self.hasStarted = false
        }
    }

    /// WaterNetworkClient의 transport 인자로 전달합니다.
    public func makeTransport() -> WaterSessionTransport {
        WaterSessionTransport(synchronizer: self)
    }

    /// 관찰을 시작하고 기존 쿠키를 합칩니다. 첫 호출만 초기 충돌 정책을 사용합니다.
    public func start() async {
        await enqueue {
            await self.reconcile(preference: self.hasSynchronized ? .preferWeb : self.initialConflictPolicy)
        }
    }

    /// 웹 로그인 완료 후 즉시 네이티브 요청을 할 때 사용할 수 있는 동기화 장벽입니다.
    public func synchronizeFromWeb() async {
        await enqueue { await self.reconcile(preference: .preferWeb) }
    }

    /// 앱 로그인 완료 후 웹뷰를 열기 전에 호출할 수 있습니다.
    public func synchronizeFromNative() async {
        await enqueue { await self.reconcile(preference: .preferNative) }
    }

    /// 외부 네트워크 구현의 로그인 결과 쿠키를 설치합니다. 전체 배치를 검증한 뒤 반영합니다.
    public func setCookiesFromNative(_ cookies: [HTTPCookie]) async throws {
        guard cookies.allSatisfy(scope.contains) else { throw WaterSessionError.cookieOutsideScope }
        await enqueue {
            // 웹의 아직 반영되지 않은 변경을 먼저 처리합니다.
            await self.reconcile(preference: .preferWeb)
            for cookie in cookies {
                if cookie.expiresDate.map({ $0 <= Date() }) ?? false {
                    self.nativeStorage.deleteCookie(cookie)
                } else {
                    self.nativeStorage.setCookie(cookie)
                }
            }
            await self.reconcile(preference: .preferNative)
        }
    }

    /// 민감한 값 없이 세션 쿠키 개수만 조회합니다. 로그인 유효성은 서버에서 확인하세요.
    public func cookieCounts() async -> (native: Int, web: Int) {
        await start()
        let native = WaterSessionCookieSnapshot(nativeStorage.cookies ?? [], scope: scope)
        let web = WaterSessionCookieSnapshot(await webCookieStore.allCookies(), scope: scope)
        return (native.cookies.count, web.cookies.count)
    }

    /// 로컬 로그아웃: 지정한 쿠키만 양쪽에서 삭제하고 진행 중인 네이티브 요청을 취소합니다.
    /// 서버 로그아웃을 먼저 수행하고 웹의 진행 중인 로그인/요청도 중단해야 합니다.
    public func clearSession() async {
        generation += 1
        nativeSession.invalidateAndCancel()
        let configuration = URLSessionConfiguration.ephemeral
        let replacementStorage = configuration.httpCookieStorage!
        // 취소된 이전 세션의 늦은 Set-Cookie 응답이 새 로그인 상태를 복구하지 않게 저장소도 교체합니다.
        for cookie in nativeStorage.cookies ?? [] where !scope.contains(cookie) {
            replacementStorage.setCookie(cookie)
        }
        nativeStorage = replacementStorage
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        nativeSession = URLSession(configuration: configuration)
        await enqueue {
            for cookie in self.nativeStorage.cookies ?? [] where self.scope.contains(cookie) {
                self.nativeStorage.deleteCookie(cookie)
            }
            for cookie in await self.webCookieStore.allCookies() where self.scope.contains(cookie) {
                await self.webCookieStore.deleteCookie(cookie)
            }
            self.previous = [:]
            WaterDebugLogger.event("앱·웹 세션 쿠키 삭제 완료")
        }
    }

    @objc(cookiesDidChangeInCookieStore:)
    public func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { [weak self] in
            guard let self else { return }
            await self.enqueue { [weak self] in
                guard let self, self.hasStarted else { return }
                await self.reconcile(preference: .preferWeb)
            }
        }
    }

    fileprivate func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        let requestGeneration = generation
        await start()
        guard requestGeneration == generation else { throw CancellationError() }
        try Task.checkCancellation()
        let session = nativeSession
        do {
            let response = try await session.data(for: request)
            guard requestGeneration == generation else { throw CancellationError() }
            await synchronizeFromNative()
            guard requestGeneration == generation else { throw CancellationError() }
            return response
        } catch {
            if requestGeneration == generation { await synchronizeFromNative() }
            throw error
        }
    }

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) async {
        let previousOperation = pendingOperation
        let task = Task { @MainActor in
            await previousOperation?.value
            await operation()
        }
        pendingOperation = task
        await task.value
    }

    private func reconcile(preference: WaterSessionConflictPolicy) async {
        // 초기 조회가 WebKit 네트워크 저장소 생성을 마친 뒤 관찰을 등록합니다.
        let web = WaterSessionCookieSnapshot(await webCookieStore.allCookies(), scope: scope)
        if !hasStarted {
            hasStarted = true
            webCookieStore.add(self)
        }
        let native = WaterSessionCookieSnapshot(nativeStorage.cookies ?? [], scope: scope)
        let merged = WaterSessionCookieSnapshot.merged(native: native, web: web, previous: previous, preference: preference)
        for (key, cookie) in native.cookies where merged[key] == nil {
            nativeStorage.deleteCookie(cookie)
        }
        for (key, cookie) in web.cookies where merged[key] == nil {
            await webCookieStore.deleteCookie(cookie)
        }
        for (key, cookie) in merged {
            if !WaterSessionCookieSnapshot.equivalent(native.cookies[key], cookie) { nativeStorage.setCookie(cookie) }
            if !WaterSessionCookieSnapshot.equivalent(web.cookies[key], cookie) {
                await webCookieStore.setCookie(cookie)
            }
        }
        previous = merged
        hasSynchronized = true
    }
}

/// 요청 전에 웹 쿠키를 가져오고 응답의 Set-Cookie를 반환 전에 웹으로 반영합니다.
public struct WaterSessionTransport: WaterNetworkTransport {
    private let synchronizer: WaterSessionSynchronizer

    @MainActor
    fileprivate init(synchronizer: WaterSessionSynchronizer) { self.synchronizer = synchronizer }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await synchronizer.data(for: request)
    }
}
#endif
