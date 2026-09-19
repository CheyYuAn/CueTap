import Foundation
import XCTest

final class RuntimeSettingsTests: XCTestCase {
    func testDefaultDirectoriesAndOverrideKeepLogsAndDataSeparate() throws {
        let paths = RuntimePaths(environment: [:])
        let home = FileManager.default.homeDirectoryForCurrentUser
        XCTAssertEqual(paths.directory.path, home.appendingPathComponent("Library/Application Support/CueTap").path)
        XCTAssertEqual(paths.log.path, home.appendingPathComponent("Library/Logs/CueTap/runtime.log").path)
        let isolated = RuntimePaths(environment: ["CUETAP_HOME": "/tmp/CueTap-isolated"])
        XCTAssertEqual(isolated.log.path, "/tmp/CueTap-isolated/logs/runtime.log")
        XCTAssertEqual(isolated.configurations.path, "/tmp/CueTap-isolated/configurations")
    }
    func testLegacyLogMovesOnceWithoutLosingContents() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap-logs-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths(environment: ["CUETAP_HOME": root.path])
        try paths.prepare()
        let old = root.appendingPathComponent("runtime.log")
        let data = Data("previous diagnostics".utf8)
        try data.write(to: old)
        try paths.prepareLog()
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        let archives = try FileManager.default.contentsOfDirectory(at: paths.logDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(archives.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(archives.first)), data)
        try paths.prepareLog()
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: paths.logDirectory.path).count, 1)
    }
    func testSettingsRoundTripAndProfileIsolation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap-settings-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths(environment: ["CUETAP_HOME": root.path])
        XCTAssertEqual(try paths.read().hotkey, "cmd+shift+r")
        try paths.save(RuntimeSettings(configurationPath: "/example/file.json", hotkey: "ctrl+option+k"))
        XCTAssertEqual(try paths.read().configurationPath, "/example/file.json")
        XCTAssertEqual(try paths.read().hotkey, "ctrl+option+k")
        XCTAssertEqual(paths.portName, RuntimePaths(environment: ["CUETAP_HOME": root.path]).portName)
        XCTAssertNotEqual(paths.portName, RuntimePaths(environment: ["CUETAP_HOME": root.path + "other"]).portName)
    }
    func testInvalidSavedSettingsFailExplicitly() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap-settings-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths(environment: ["CUETAP_HOME": root.path])
        try paths.prepare()
        try Data(#"{"hotkey":"cmd+r"}"#.utf8).write(to: paths.settings)
        XCTAssertThrowsError(try paths.read())
    }
}
