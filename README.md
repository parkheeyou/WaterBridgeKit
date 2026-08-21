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
