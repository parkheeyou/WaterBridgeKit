import Foundation

/// API 호출 시 endpoint에 전달할 요청 데이터입니다.
public enum WaterAPIRequest: Sendable {
    case plain
    case query([WaterQueryItem])
    case queryEncodable(any Encodable & Sendable)
    case json(any Encodable & Sendable)
    case form([WaterQueryItem])
    case raw(Data, contentType: String? = nil)
}

/// URL query 또는 form 데이터의 단일 항목입니다.
public struct WaterQueryItem: Sendable, Equatable {
    public let name: String
    public let value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }
}
