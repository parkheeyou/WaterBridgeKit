# WaterBridgeKit

`WaterBridgeKit` 의 주요 기능
- `WaterWebView` + 기본 브릿지 처리(`water://~`)
- 크래쉬 발생시 `.log` 파일로 확인 가능
- 로그 콘솔 뷰 제공(앱에서 바로 로그 확인 가능)
- URLSession 기반 타입 안전 API 통신 모듈

## Requirements

- iOS 17 이상
- Swift 6.1 이상
- Xcode 16 이상

## Installation

GitHub 저장소를 생성한 뒤 실제 저장소 URL로 아래 값을 교체합니다.

```swift
dependencies: [
    .package(
        url: "https://github.com/<owner>/WaterBridgeKit.git",
        from: "0.1.0"
    )
]
```

사용할 타깃에는 라이브러리 제품을 연결합니다.

```swift
.product(name: "WaterBridgeKit", package: "WaterBridgeKit")
```

## Usage

```swift
import SwiftUI
import WaterBridgeKit

struct ContentView: View {
    var body: some View {
        WaterWebView(
            url: URL(string: "https://example.com")!
        )
    }
}
```

기본 WebKit 메시지 채널은 `Bridge`입니다.

```javascript
window.webkit.messageHandlers.Bridge.postMessage(message);
```

현재 제공하는 브릿지 API는 다음과 같습니다.

- `water://routeApiList` version 2
- `water://nativeInfo` version 2

## Custom channel and routes

사용 앱에서 채널 이름을 변경하고 앱 전용 브릿지를 추가할 수 있습니다.

```swift
import SwiftUI
import WaterBridgeKit

private let bridgeConfiguration = WaterBridgeConfiguration(
    channel: "BCUBridge",
    additionalRoutes: [
        WaterBridgeRoute(
            api: "water://appInfo",
            version: 1
        ) { message in
            let requestData = message.data as? [String: Any]

            return WaterBridgeResponse.success(
                data: [
                    "appName": "BCU",
                    "requestData": requestData ?? [:]
                ]
            ).value
        }
    ]
)

struct ContentView: View {
    var body: some View {
        WaterWebView(
            url: URL(string: "https://example.com")!,
            configuration: bridgeConfiguration
        )
    }
}
```

웹에서는 설정한 채널 이름을 사용합니다.

```javascript
window.webkit.messageHandlers.BCUBridge.postMessage(message);
```

추가 Route는 `water://routeApiList` 결과에도 자동으로 포함됩니다.
기본 Route와 동일한 API를 추가하면 앱에서 등록한 Route가 우선합니다.

## Network

네트워크 모듈은 외부 라이브러리 없이 `URLSession`과 async/await를 사용합니다.
API 목록은 `WaterAPIEndpoint`를 채택한 enum으로 별도 관리합니다.

```swift
enum AppAPI: WaterAPIEndpoint {
    case users
    case user(id: Int)
    case login

    var path: String {
        switch self {
        case .users:
            "/users"
        case let .user(id):
            "/users/\(id)"
        case .login:
            "/login"
        }
    }

    var method: WaterHTTPMethod {
        switch self {
        case .users, .user:
            .get
        case .login:
            .post
        }
    }
}
```

기본 URL과 공통 헤더를 설정해 클라이언트를 생성합니다.

```swift
let apiClient = WaterNetworkClient<AppAPI>(
    configuration: WaterNetworkConfiguration(
        baseURL: URL(string: "https://api.example.com/v1")!,
        headers: [
            "Accept": "application/json"
        ],
        headerProvider: {
            // 요청 시점마다 최신 인증 값을 반환할 수 있습니다.
            ["Authorization": "Bearer ACCESS_TOKEN"]
        }
    )
)
```

요청과 응답 모델은 `Sendable`을 함께 채택합니다.

```swift
struct LoginRequest: Encodable, Sendable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable, Sendable {
    let accessToken: String
}

let result = await apiClient.request(
    .login,
    request: .json(
        LoginRequest(
            email: "water@example.com",
            password: "password"
        )
    ),
    response: LoginResponse.self
)

switch result {
case let .success(response):
    print(response.accessToken)
case let .failure(error):
    print(error.localizedDescription)
}
```

query 모델도 직접 전달할 수 있습니다.

```swift
struct UserQuery: Encodable, Sendable {
    let page: Int
    let keyword: String
}

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

let result = await apiClient.request(
    .users,
    request: .queryEncodable(
        UserQuery(page: 1, keyword: "water")
    ),
    response: [User].self
)
```

서버의 실패 응답도 별도 모델로 디코딩하려면 `errorResponse`를 지정합니다.

```swift
struct APIErrorResponse: Decodable, Sendable {
    let code: String
    let message: String
}

let result = await apiClient.request(
    .login,
    request: .json(loginRequest),
    response: LoginResponse.self,
    errorResponse: APIErrorResponse.self
)

switch result {
case let .success(response, httpResponse):
    print(response, httpResponse.statusCode)
case let .failure(failure):
    print(failure.error)
    print(failure.body?.message ?? "서버 오류")
}
```

`.plain`, `.query`, `.queryEncodable`, `.json`, `.form`, `.raw` 요청을 지원합니다.
completion 방식도 동일한 `request` 함수로 사용할 수 있으며 반환되는 `Task`를
취소하면 URLSession 요청도 함께 취소됩니다.

API 요청과 응답의 메서드, 경로, 상태 코드, 소요 시간은 DEBUG 로그 콘솔의
`API` 카테고리에 자동 기록됩니다. 요청·응답 본문 로그는 민감 정보 노출을
방지하기 위해 기본적으로 꺼져 있습니다. 필요한 개발 환경에서만
`isBodyLoggingEnabled: true`로 활성화해야 합니다.

## In-app debug console

`WaterWebView`는 DEBUG 빌드에서 우측 하단에 `로그` 버튼을 자동으로 표시합니다.
버튼을 누르면 Xcode를 연결하지 않아도 현재 실행 중 발생한 로그를 앱 안에서
확인할 수 있습니다.

콘솔에서는 다음 로그를 카테고리별로 확인할 수 있습니다.

- `WEBVIEW`: 웹뷰 요청, 로딩 시작·완료 및 오류
- `BRIDGE`: 웹 브릿지 수신, 응답, 콜백 및 거절
- `CRASH`: 크래시 리포터 상태
- `EVENT`: 앱에서 직접 기록한 사용자 이벤트
- `API`: 앱에서 직접 기록한 API 요청과 응답
- `CUSTOM`: 그 밖의 앱 로그

콘솔은 최신 로그를 위에 표시하며 전체 로그 복사와 초기화를 지원합니다.
로그는 메모리에 최대 1,000개까지 저장되고 Release 빌드에서는 버튼 표시와
로그 수집이 모두 비활성화됩니다.

필요하면 특정 `WaterWebView`에서 콘솔 버튼을 끌 수 있습니다.

```swift
let configuration = WaterBridgeConfiguration(
    showsDebugConsole: false
)

WaterWebView(
    url: URL(string: "https://example.com")!,
    configuration: configuration
)
```

웹뷰가 아닌 일반 SwiftUI 화면에서도 같은 콘솔을 사용할 수 있습니다.

```swift
struct SettingsView: View {
    var body: some View {
        SettingsContent()
            .waterDebugConsole()
    }
}
```

앱 고유 이벤트와 API 통신은 `WaterDebugLogger`로 기록합니다.

```swift
WaterDebugLogger.event("로그인 버튼 선택")
WaterDebugLogger.api("POST /login request started")
WaterDebugLogger.api("POST /login -> 200")

WaterDebugLogger.log(
    "응답 디코딩 실패",
    category: .api,
    level: .error
)
```

API 요청·응답을 기록할 때에는 인증 토큰, 개인정보 등 민감한 값을 제거하거나
마스킹한 문자열을 전달해야 합니다.

## Crash reports

앱 진입점에서 크래시 수집기를 한 번 활성화합니다.

```swift
import SwiftUI
import WaterBridgeKit

@main
struct MyApp: App {
    init() {
        do {
            let result = try WaterCrashReporter.shared.start()
            if let reportURL = result.recoveredReportURL {
                print("Recovered crash report:", reportURL.path)
            }
        } catch {
            print("Crash reporter failed:", error)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

크래시가 발생한 순간에는 PLCrashReporter가 안전한 원본 보고서를 기록합니다.
다음 앱 실행에서 `start()`가 이를 사람이 읽을 수 있는 `.crash.log` 파일로
변환해 Application Support의 `WaterBridgeKit/CrashReports`에 저장합니다.

```swift
let urls = try WaterCrashReporter.shared.reportURLs()
let latestURL = try WaterCrashReporter.shared.latestReportURL()
let latestText = try WaterCrashReporter.shared.latestReportText()
try WaterCrashReporter.shared.removeAllReports()
```

기본적으로 최근 10개를 보관합니다. 저장 경로와 보관 개수는 변경할 수 있습니다.

```swift
try WaterCrashReporter.shared.start(
    configuration: .init(
        directoryURL: customDirectoryURL,
        maximumReportCount: 20
    )
)
```

디버거 연결 중에는 디버깅 세션과의 충돌을 피하기 위해 수집기를 활성화하지
않습니다. 실제 수집 동작은 Xcode에서 앱을 실행한 뒤 디버거 연결을 해제하거나
릴리스 빌드에서 확인해야 합니다.

## iOS 권한 확인 및 요청

`WaterPermissionManager`는 카메라(`camera`), 마이크(`microphone`), 앱 사용 중 위치(`location`), 사진 라이브러리 읽기·쓰기(`photos`)를 지원합니다. iOS 전용 기능입니다.

```swift
import SwiftUI
import WaterBridgeKit

struct PermissionExampleView: View {
    @StateObject private var permissions = WaterPermissionManager()

    var body: some View {
        VStack {
            Button("카메라 사용") {
                Task {
                    if await permissions.ensurePermission(.camera) {
                        // 카메라 화면 표시
                    }
                }
            }
            Text(permissions.statuses[.camera]?.title ?? "확인 중")
        }
        .waterPermissionAlerts(using: permissions)
    }
}
```

- `status(for:)`: 시스템 창 없이 상태 조회. `refresh()`는 지원 권한 전체를 갱신합니다.
- `request(_:)`: 미결정 상태에서만 시스템 창을 표시하고 결과를 반환합니다. 별도 UI에서 직접 처리할 때 사용합니다. 설정 안내를 자동 표시하지 않습니다.
- `ensurePermission(_:)`: 시스템 요청 후 허용 여부를 반환하고, 미허용 시 앱 안내를 준비합니다. 같은 인스턴스를 `.waterPermissionAlerts(using:)`에 연결해야 안내가 보입니다.
- 이미 거부한 권한은 시스템 창을 다시 띄울 수 없으므로 앱 설정 이동을 안내합니다. 사용자가 취소하면 기능 진행을 중단합니다.
- `restricted`는 스크린 타임·관리 정책 안내만 표시합니다. 위치 서비스 전체가 꺼져 있으면 전역 설정 경로를 안내합니다. 설정 버튼은 공개 API로 앱 설정을 열며, 전역 위치 서비스 설정으로 직접 이동하지 않습니다.
- 사진의 `limited`는 사용 가능한 권한으로 취급합니다. 선택한 사진만 접근할 수 있으므로 전체 라이브러리 접근을 가정하면 안 됩니다.
- 설정에서 돌아오면 modifier가 상태를 갱신합니다. 권한이 허용되어도 이전 기능을 자동 실행하지 않으며 다시 버튼을 선택하면 됩니다.
- 앱이 활성화된 상태에서 요청하세요. 동일 manager의 중복 요청은 막습니다. 여러 화면에서도 하나의 manager를 공유하고 안내 modifier는 표시 중인 화면에 하나만 연결하세요.

사용 앱의 **Info.plist**에 요청할 권한의 사용 목적을 추가해야 합니다. 패키지 자체에 설정해도 사용 앱에는 적용되지 않습니다.

| 권한 | Info.plist 키 |
| --- | --- |
| 카메라 | `NSCameraUsageDescription` |
| 마이크 | `NSMicrophoneUsageDescription` |
| 앱 사용 중 위치 | `NSLocationWhenInUseUsageDescription` |
| 사진 읽기·쓰기 | `NSPhotoLibraryUsageDescription` |

미결정 상태에서 사용 목적이 없거나 비어 있으면 시스템 요청 전에 오류를 반환하여 설정 누락으로 인한 종료를 방지합니다. 백그라운드 위치·알림·블루투스 권한과 웹뷰의 웹 콘텐츠 권한 위임은 이 API에 포함하지 않습니다.

## 앱·웹 쿠키 세션 동기화

`WaterSessionSynchronizer`는 WebKit의 `WKHTTPCookieStore`와 전용 `URLSession` 쿠키 저장소를 연결합니다. 하나의 로그인 서비스에는 하나의 인스턴스를 유지하고, 웹뷰와 앱 API 클라이언트에 **같은 인스턴스**를 연결하세요.

```swift
import SwiftUI
import WaterBridgeKit

@MainActor
final class AppSession {
    let synchronizer: WaterSessionSynchronizer
    let apiClient: WaterNetworkClient<AppAPI>

    init() throws {
        synchronizer = try WaterSessionSynchronizer(
            allowedDomains: ["example.com"],
            cookieNames: ["SESSIONID", "XSRF-TOKEN"]
        )
        apiClient = WaterNetworkClient<AppAPI>(
            configuration: .init(baseURL: URL(string: "https://example.com/api")!),
            transport: synchronizer.makeTransport()
        )
    }
}

// 웹뷰를 만들 때 기존 앱·웹 쿠키 동기화가 완료된 후 첫 URL을 로드합니다.
WaterWebView(
    url: URL(string: "https://example.com/login")!,
    configuration: .init(sessionSynchronizer: appSession.synchronizer)
)
```

`AppAPI`는 Network 섹션처럼 `WaterAPIEndpoint`를 채택한 앱의 endpoint enum입니다. `AppSession`은 앱 수준에서 소유하세요. 일반 `URLSession.shared`를 사용하는 기존 클라이언트는 자동으로 연결되지 않습니다.

### 로그인 흐름

- **앱 로그인:** 위 `apiClient`로 로그인 API 호출 → URLSession이 응답의 `Set-Cookie`를 저장 → transport가 웹 저장소에 반영한 뒤 응답 반환 → 같은 세션으로 웹뷰 사용.
- **웹 로그인:** 서버가 웹뷰에 `Set-Cookie` 전달 → 쿠키 변경 observer가 앱 저장소에 반영 → 다음 앱 API 요청 직전에도 동기화 장벽을 수행.
- 브릿지로 웹 로그인 완료 알림을 받은 직후에는 `await synchronizer.synchronizeFromWeb()`를 호출한 뒤 로그인 확인 API를 요청할 수 있습니다. JavaScript에서 세션 쿠키 값을 읽거나 네이티브에 직접 전달할 필요가 없습니다.
- 다른 네트워크 라이브러리로 로그인했다면 그 구현이 저장한 **실제 HTTPCookie**를 `try await synchronizer.setCookiesFromNative(cookies)`로 설치하세요. 요청 전 동기화 및 응답/리다이렉트에서 쿠키 저장은 해당 구현에서 처리해야 합니다.
- `await synchronizer.start()`로 웹뷰가 없어도 관찰과 초기 동기화를 시작합니다. 웹뷰에 연결하거나 transport를 사용하면 자동 시작합니다. `stopObserving()`는 자동 관찰을 중단하며 다음 start/요청/명시적 동기화에서 다시 시작합니다.

### 공유 범위와 쿠키 속성

`allowedDomains`와 `cookieNames`는 필수이며 서버의 실제 설정에 맞춰 지정합니다. `example.com`은 해당 도메인과 `api.example.com` 같은 하위 도메인의 지정된 이름 쿠키를 허용합니다. `example.com.evil.test` 같은 유사 도메인은 허용하지 않습니다. 쿠키의 원래 Domain/Path/Secure/HttpOnly/만료 속성을 유지하며, 같은 이름이라도 도메인·경로가 다르면 별도 쿠키로 처리합니다.

도메인 허용 목록은 쿠키의 Domain을 확장하는 기능이 아닙니다. 웹의 host-only 쿠키가 `www.example.com`에 설정돼 있으면 `api.example.com`으로 전송할 수 없습니다. 양쪽 호스트에서 같은 쿠키를 쓰려면 서버가 적절한 Domain을 설정하거나 공통 인증 서버로 세션을 교환해야 합니다. 서버가 CSRF 쿠키·헤더를 요구하면 쿠키 이름을 함께 등록하고 요청 헤더도 서버 규약에 맞게 설정하세요. Cookie 헤더는 직접 덮어쓰지 말고 URLSession이 URL에 맞춰 생성하도록 두세요.

HttpOnly 쿠키는 JavaScript로 주입하지 않고 네이티브 저장소 API로 공유합니다. 세션 쿠키 값은 동기화 모듈의 로그에 기록하지 않으며 `cookieCounts()`는 개수만 제공합니다. 개수가 1 이상이어도 인증 성공을 뜻하지 않으므로 서버의 세션 확인 API로 유효성을 판단하세요.

기본 WebKit 저장소는 `.default()`입니다. 네이티브 저장소는 인스턴스 전용 메모리 저장소이며 다음 앱 실행 시 웹 저장소에 남아 있는 범위 내 쿠키를 가져옵니다. 재실행 후 유지 여부는 쿠키 만료 및 WebKit 정책에 따릅니다. 메모리 전용 양쪽 저장소가 필요하면 `websiteDataStore: .nonPersistent()`를 전달하세요. 앱에서 이미 저장한 초기 쿠키를 복원할 때는 `initialCookies:`를 전달할 수 있습니다.

### 충돌과 로그아웃

변경된 쪽의 쿠키를 반영하고 삭제도 전파합니다. 양쪽이 같은 쿠키를 동시에 변경하면 `synchronizeFromWeb()`는 웹을, `synchronizeFromNative()`는 앱을 우선합니다. 초기 동기화의 충돌 정책은 기본 `.preferWeb`이며 `initialConflictPolicy: .preferNative`로 바꿀 수 있습니다. 저장소 간 원자적 트랜잭션은 아니므로 서로 다른 계정으로 앱·웹 로그인을 동시에 실행하지 마세요.

```swift
// 서버 로그아웃 성공 이후 수행합니다.
// 진행 중인 웹 로그인/요청도 앱에서 중단하고 로그인 화면으로 전환하세요.
await appSession.synchronizer.clearSession()
```

`clearSession()`은 지정한 도메인·이름의 쿠키만 양쪽에서 삭제합니다. 다른 쿠키, 캐시, localStorage는 삭제하지 않습니다. 진행 중인 관리 대상 네이티브 요청을 취소하고 네이티브 저장소를 교체하므로 이전 응답이 새 세션으로 반영되지 않습니다. 이 API 자체는 서버 세션을 폐기하지 않습니다. 서버 로그아웃 호출과 웹의 진행 중인 요청 정리는 앱이 담당합니다.

이 기능은 쿠키 기반입니다. Bearer 토큰·localStorage 토큰·다른 서비스 간 SSO는 별도 인증 연결이 필요하며 현재 기능에 포함하지 않습니다.

관련 API: [Apple WKHTTPCookieStore](https://developer.apple.com/documentation/webkit/wkhttpcookiestore), [URLSessionConfiguration.httpCookieStorage](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/httpcookiestorage).
