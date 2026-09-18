import Foundation
import XCTest

final class ConfigurationCLITests: XCTestCase {
    private var folder: URL!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap config test \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }

    private func run(_ arguments: [String]) throws -> (Int32, String) {
        let process = Process()
        process.executableURL = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("cuetap")
        process.currentDirectoryURL = folder
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: output, as: UTF8.self))
    }

    func testDefaultExampleCanValidateFromUnrelatedDirectory() throws {
        let result = try run(["--validate"])
        XCTAssertEqual(result.0, 0)
        XCTAssertTrue(result.1.contains("38 个动作"))
    }
    func testCustomFileWithSpacesAndRelativePathIsLoaded() throws {
        let file = folder.appendingPathComponent("custom script.json")
        try Data(#"{"version":1,"name":"Custom","actions":[{"type":"text","value":"Z9{}"},{"type":"key","key":"enter"}]}"#.utf8).write(to: file)
        for path in [file.path, "custom script.json"] {
            let result = try run(["--script", path, "--validate"])
            XCTAssertEqual(result.0, 0)
            XCTAssertTrue(result.1.contains("Custom，5 个动作"))
        }
    }
    func testMissingAndInvalidFilesFailBeforeStartingInterception() throws {
        let missing = try run(["--script", "missing.json"])
        XCTAssertEqual(missing.0, 1)
        XCTAssertTrue(missing.1.contains("missing.json"))
        let file = folder.appendingPathComponent("bad.json")
        try Data(#"{"version":1,"name":"Bad","actions":[{"type":"key","key":"typo"}]}"#.utf8).write(to: file)
        let invalid = try run(["--script", file.path])
        XCTAssertEqual(invalid.0, 1)
        XCTAssertTrue(invalid.1.contains("actions[0].key"))
        XCTAssertEqual(try run(["--script"]).0, 2)
    }
}
