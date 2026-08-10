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

웹에서는 주입된 `window.WaterBridge`를 통해 네이티브 API를 호출할 수 있습니다.

```javascript
window.WaterBridge.routeApiList({}, (response) => {
  console.log(response.status);
  console.log(response.data);
});
```

현재 제공하는 브릿지 API는 다음과 같습니다.

- `water://routeApiList` version 2
- `water://nativeInfo` version 2
