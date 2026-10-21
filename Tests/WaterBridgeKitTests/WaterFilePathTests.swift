import Foundation
import XCTest
@testable import WaterBridgeKit

final class WaterFilePathTests: XCTestCase {
    func testRootIsSandboxHome() {
        XCTAssertEqual(WaterFilePath.rootFolderPath(), NSHomeDirectory())
        XCTAssertTrue(WaterFilePath.rootFolderPath().hasPrefix("/"))
    }

    func testDownloadDirectoryCreationIsRepeatableAndPreservesContents() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = try WaterFilePath.downloadPath(in: root)
        let file = URL(fileURLWithPath: path).appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: file)
        XCTAssertEqual(path, root.appendingPathComponent("Downloads").path)
        XCTAssertEqual(try WaterFilePath.downloadPath(in: root), path)
        XCTAssertEqual(try Data(contentsOf: file), Data("keep".utf8))
    }

    func testDownloadRejectsFileAtDirectoryPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("Downloads"))
        XCTAssertThrowsError(try WaterFilePath.downloadPath(in: root))
    }

    func testWWWRequiresExistingDirectoryAndDoesNotCreateOne() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let www = root.appendingPathComponent("www")
        XCTAssertThrowsError(try WaterFilePath.wwwPath(in: root))
        XCTAssertFalse(FileManager.default.fileExists(atPath: www.path))
        try Data().write(to: www)
        XCTAssertThrowsError(try WaterFilePath.wwwPath(in: root))
        try FileManager.default.removeItem(at: www)
        try FileManager.default.createDirectory(at: www, withIntermediateDirectories: true)
        XCTAssertEqual(try WaterFilePath.wwwPath(in: root), www.path)
    }
}
