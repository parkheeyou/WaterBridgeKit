/// WaterBridgeKit 네트워크 모듈이 지원하는 HTTP 메서드입니다.
public enum WaterHTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
}
