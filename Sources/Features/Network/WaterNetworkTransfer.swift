import Foundation

public struct WaterUploadFile: Sendable {
    public let url: URL
    public let name: String
    public let fileName: String
    public let mimeType: String

    public init(url: URL, name: String, fileName: String? = nil, mimeType: String = "application/octet-stream") {
        self.url = url
        self.name = name
        self.fileName = fileName ?? url.lastPathComponent
        self.mimeType = mimeType
    }
}

public struct WaterDownloadResponse: Sendable {
    public let fileURL: URL
    public let statusCode: Int
    public let headers: [String: String]
    public let url: URL?
}

public extension WaterNetworkClient {
    /// 원본 파일을 HTTP body로 전송합니다. 메서드는 endpoint 설정을 따릅니다.
    func upload<Response: Decodable & Sendable>(
        _ endpoint: API, fileURL: URL, contentType: String = "application/octet-stream",
        response: Response.Type = Response.self
    ) async -> Result<Response, WaterNetworkError> {
        do {
            try WaterMultipartBody.validateFile(fileURL)
            guard !contentType.contains("\r"), !contentType.contains("\n") else {
                throw WaterNetworkError.requestEncoding(message: "잘못된 Content-Type입니다.")
            }
            let result: WaterNetworkResult<Response, WaterEmptyResponse> = await perform(
                endpoint, requestData: .plain, responseType: response,
                failureType: WaterEmptyResponse.self, uploadFile: fileURL, contentType: contentType
            )
            switch result {
            case let .success(value, _): return .success(value)
            case let .failure(failure): return .failure(failure.error)
            }
        } catch { return .failure(Self.transferError(error)) }
    }

    /// 파일/문자열 필드를 임시 파일로 구성하므로 파일 전체를 메모리에 적재하지 않습니다.
    func upload<Response: Decodable & Sendable>(
        _ endpoint: API, files: [WaterUploadFile], fields: [WaterQueryItem] = [],
        response: Response.Type = Response.self
    ) async -> Result<Response, WaterNetworkError> {
        do {
            let boundary = "WaterBridge-\(UUID().uuidString)"
            let body = try WaterMultipartBody.make(files: files, fields: fields, boundary: boundary)
            defer { try? FileManager.default.removeItem(at: body) }
            return await upload(endpoint, fileURL: body,
                                contentType: "multipart/form-data; boundary=\(boundary)", response: response)
        } catch { return .failure(Self.transferError(error)) }
    }

    /// 부모 디렉터리는 미리 생성해야 합니다. 기존 목적지 파일은 덮어쓰지 않습니다.
    func download(
        _ endpoint: API, request: WaterAPIRequest = .plain, to destination: URL
    ) async -> Result<WaterDownloadResponse, WaterNetworkError> {
        do {
            guard destination.isFileURL else { throw WaterNetworkError.file(message: "저장 경로는 파일 URL이어야 합니다.") }
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw WaterNetworkError.file(message: "저장 경로에 파일이 이미 존재합니다.")
            }
            let urlRequest = try WaterURLRequestBuilder.makeRequest(endpoint: endpoint, requestData: request, configuration: configuration)
            let (temporary, response) = try await transport.download(for: urlRequest)
            defer { try? FileManager.default.removeItem(at: temporary) }
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw WaterNetworkError.invalidResponse }
            guard configuration.validStatusCodes.contains(http.statusCode) else {
                // 실패 응답도 대용량일 수 있으므로 최대 64 KiB만 보관합니다.
                let handle = try FileHandle(forReadingFrom: temporary)
                defer { try? handle.close() }
                let body = try handle.read(upToCount: 65_536) ?? Data()
                throw WaterNetworkError.unacceptableStatusCode(statusCode: http.statusCode, data: body)
            }
            do { try FileManager.default.moveItem(at: temporary, to: destination) }
            catch { throw WaterNetworkError.file(message: error.localizedDescription) }
            let headers = http.allHeaderFields.reduce(into: [String: String]()) {
                $0[String(describing: $1.key)] = String(describing: $1.value)
            }
            return .success(WaterDownloadResponse(fileURL: destination, statusCode: http.statusCode, headers: headers, url: http.url))
        } catch { return .failure(Self.transferError(error)) }
    }

    private static func transferError(_ error: Error) -> WaterNetworkError {
        if let error = error as? WaterNetworkError { return error }
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return .cancelled }
        return .transport(message: error.localizedDescription)
    }
}

package enum WaterMultipartBody {
    static func validateFile(_ url: URL) throws {
        guard url.isFileURL,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
              FileManager.default.isReadableFile(atPath: url.path) else {
            throw WaterNetworkError.file(message: "읽을 수 있는 일반 파일이 필요합니다: \(url.lastPathComponent)")
        }
    }

    private static func quoted(_ value: String) throws -> String {
        guard !value.contains(where: { $0.isNewline || $0 == "\0" }) else {
            throw WaterNetworkError.requestEncoding(message: "multipart 헤더에 줄바꿈을 사용할 수 없습니다.")
        }
        return value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func make(files: [WaterUploadFile], fields: [WaterQueryItem], boundary: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw WaterNetworkError.file(message: "임시 업로드 파일을 생성할 수 없습니다.")
        }
        do {
            let output = try FileHandle(forWritingTo: url)
            defer { try? output.close() }
            func write(_ text: String) throws { try output.write(contentsOf: Data(text.utf8)) }
            for field in fields {
                try Task.checkCancellation()
                try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(try quoted(field.name))\"\r\n\r\n\(field.value ?? "")\r\n")
            }
            for file in files {
                try validateFile(file.url)
                guard !file.mimeType.contains(where: { $0.isNewline || $0 == "\0" }) else {
                    throw WaterNetworkError.requestEncoding(message: "잘못된 MIME type입니다.")
                }
                try write("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(try quoted(file.name))\"; filename=\"\(try quoted(file.fileName))\"\r\nContent-Type: \(file.mimeType)\r\n\r\n")
                let input = try FileHandle(forReadingFrom: file.url)
                defer { try? input.close() }
                while true {
                    try Task.checkCancellation()
                    guard let chunk = try input.read(upToCount: 65_536), !chunk.isEmpty else { break }
                    try output.write(contentsOf: chunk)
                }
                try write("\r\n")
            }
            try write("--\(boundary)--\r\n")
            return url
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
}
