import Foundation
import XCTest

final class DoctorTests: XCTestCase {
    private var root: URL!
    private var paths: RuntimePaths { RuntimePaths(environment: ["CUETAP_HOME": root.appendingPathComponent("profile").path]) }
    private var executable: URL { root.appendingPathComponent("cuetap") }
    private let ready = PermissionStatus(listen: true, post: true, secureInput: false, englishInputSource: true)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap-doctor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: ExampleFixture.url, to: root.appendingPathComponent("html-demo.json"))
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func absent() throws -> ControlResponse { throw ControlError("not_running", "Not running.") }

    func testFirstUseDiagnosisDoesNotCreateDataOrStartAResident() throws {
        let result = Doctor(executable: executable, paths: paths, permissions: { self.ready }, queryResident: absent).run()
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.diagnostics?.permissionsScope, "command_host")
        XCTAssertNil(result.status)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.directory.path))
        XCTAssertTrue(result.diagnostics?.findings.contains { $0.id == "resident" && $0.severity == "info" } == true)
    }

    func testMissingConfigurationAndPermissionsHaveActionableFindings() throws {
        try paths.save(RuntimeSettings(configurationPath: root.appendingPathComponent("missing.json").path))
        let saved = try Data(contentsOf: paths.settings)
        let denied = PermissionStatus(listen: false, post: false, secureInput: true, englishInputSource: false)
        let result = Doctor(executable: executable, paths: paths, permissions: { denied }, queryResident: absent).run()
        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error?.code, "diagnostic_failed")
        let failures = try XCTUnwrap(result.diagnostics?.findings.filter { $0.severity == "error" })
        for id in ["input_monitoring", "accessibility", "secure_input", "english_input_source", "configuration"] {
            XCTAssertTrue(failures.contains { $0.id == id && $0.suggestion != nil })
        }
        XCTAssertEqual(try Data(contentsOf: paths.settings), saved)
    }

    func testResidentPermissionsAreUsedWithoutChangingTheLiveState() throws {
        let live = RuntimeStatus(running: true, pid: 123, executable: executable.path, state: "on", phase: "playing", ready: true,
                                 configurationPath: root.appendingPathComponent("html-demo.json").path, position: 9, hotkey: "cmd+shift+r", permissions: ready)
        let result = Doctor(executable: executable, paths: paths,
                            permissions: { XCTFail("Do not substitute the command host's permissions for the resident's."); return self.ready },
                            queryResident: { ControlResponse(message: "Status", status: live) }).run()
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.diagnostics?.permissionsScope, "resident")
        XCTAssertEqual(result.status?.position, 9)
        XCTAssertEqual(result.status?.state, "on")
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.directory.path))
    }

    func testBrokenSettingsAndUnresponsiveResidentAreReportedTogether() throws {
        try paths.prepare()
        try Data("bad JSON".utf8).write(to: paths.settings)
        let result = Doctor(executable: executable, paths: paths, permissions: { self.ready },
                            queryResident: { throw ControlError("ipc_timeout", "Unresponsive resident.") }).run()
        XCTAssertFalse(result.ok)
        let failed = result.diagnostics?.findings.filter { $0.severity == "error" }.map(\.id) ?? []
        XCTAssertTrue(failed.contains("resident"))
        XCTAssertTrue(failed.contains("settings"))
        XCTAssertEqual(try String(contentsOf: paths.settings, encoding: .utf8), "bad JSON")
    }
}
