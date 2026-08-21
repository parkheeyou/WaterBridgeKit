/// 앱에서 별도로 관리할 API 목록이 채택하는 프로토콜입니다.
///
/// 연관 값을 가진 enum으로 구현하면 case를 추가하는 것만으로 API 목록을
/// 확장할 수 있습니다.
public protocol WaterAPIEndpoint: Sendable {
    var path: String { get }
    var method: WaterHTTPMethod { get }
    var headers: [String: String]? { get }
}

public extension WaterAPIEndpoint {
    var headers: [String: String]? { nil }
}
