import Foundation

/// 앱에서 사용하는 파일 시스템의 절대 경로를 제공합니다.
public enum WaterFilePath {
    /// 앱 데이터 샌드박스의 루트입니다. 앱 번들 경로와는 별개입니다.
    public static func rootFolderPath() -> String {
        NSHomeDirectory()
    }

    /// 앱 전용 Documents/Downloads 폴더를 생성하고 절대 경로를 반환합니다.
    /// 시스템 파일 앱의 공용 Downloads 폴더가 아닙니다.
    public static func getDownloadPath() throws -> String {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return try downloadPath(in: documents)
    }

    /// 지정한 번들 리소스 루트 바로 아래의 www 폴더입니다. 기본값은 호스트 앱 번들입니다.
    /// www는 폴더 구조를 유지하여 앱 리소스로 포함해야 하며, 읽기 전용으로 사용하세요.
    public static func getFullResourceWWWRootPath(bundle: Bundle = .main) throws -> String {
        guard let resources = bundle.resourceURL else {
            throw WaterFilePathError.resourceRootUnavailable
        }
        return try wwwPath(in: resources)
    }

    package static func downloadPath(in documents: URL) throws -> String {
        let directory = documents.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.path
    }

    package static func wwwPath(in resources: URL) throws -> String {
        let directory = resources.appendingPathComponent("www", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw WaterFilePathError.wwwDirectoryNotFound
        }
        return directory.path
    }
}

public enum WaterFilePathError: Error, LocalizedError, Sendable {
    case resourceRootUnavailable
    case wwwDirectoryNotFound

    public var errorDescription: String? {
        switch self {
        case .resourceRootUnavailable: "번들의 리소스 경로를 찾을 수 없습니다."
        case .wwwDirectoryNotFound: "번들 리소스에 www 폴더가 없습니다. 폴더 구조를 유지하여 추가하세요."
        }
    }
}
