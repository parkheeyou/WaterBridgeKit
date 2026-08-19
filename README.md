# WaterBridgeKit

`WaterBridgeKit`은 SwiftUI의 `WKWebView`와 웹 애플리케이션 사이의
`water://` JavaScript 브릿지 통신을 제공하는 Swift Package입니다.

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
