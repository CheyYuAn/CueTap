import Foundation
import XCTest

final class AgentControlIntegrationTests: XCTestCase {
    private var root: URL!
    private var executable: URL { Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("cuetap") }
    override func setUpWithError() throws {
        try KeyboardSession.checkPermissions()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap-agent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        if root != nil {
            _ = try? command(["quit"])
            try FileManager.default.removeItem(at: root)
        }
    }
    private func command(_ args: [String], using executableURL: URL? = nil) throws -> (Int32, ControlResponse) {
        let process = Process()
        process.executableURL = executableURL ?? executable
        process.arguments = args + ["--json"]
        var environment = ProcessInfo.processInfo.environment
        environment["CUETAP_HOME"] = root.appendingPathComponent("profile").path
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, try JSONDecoder().decode(ControlResponse.self, from: data))
    }
    func testStartLoadReloadHotkeyPersistenceAndQuitUseOneResidentProcess() throws {
        XCTAssertEqual(try command(["status"]).1.status?.running, false)
        let started = try command(["start", "--script", ExampleFixture.url.path])
        XCTAssertEqual(started.0, 0)
        let pid = try XCTUnwrap(started.1.status?.pid)
        XCTAssertEqual(try command(["start"]).1.status?.pid, pid)
        XCTAssertEqual(try command(["start", "--script", ExampleFixture.url.path]).1.error?.code, "already_running")
        XCTAssertEqual(try command(["hotkey", "set", "ctrl+option+k"]).1.status?.hotkey, "ctrl+option+k")
        let file = root.appendingPathComponent("custom file.json")
        func write(_ value: String) throws {
            try JSONSerialization.data(withJSONObject: ["version": 1, "name": "Custom", "actions": [["type": "text", "value": value]]]).write(to: file)
        }
        try write("Z9")
        let imported = try command(["load", file.path])
        XCTAssertEqual(imported.1.status?.actionCount, 2)
        let firstCopy = try XCTUnwrap(imported.1.status?.configurationPath)
        XCTAssertNotEqual(firstCopy, file.path)
        try write("Z9{}")
        XCTAssertEqual(try command(["reload"]).1.status?.actionCount, 2)
        let reimported = try command(["load", file.path])
        XCTAssertEqual(reimported.0, 0, reimported.1.message)
        XCTAssertEqual(reimported.1.status?.actionCount, 4)
        let managed = URL(fileURLWithPath: try XCTUnwrap(reimported.1.status?.configurationPath))
        XCTAssertNotEqual(firstCopy, managed.path)
        XCTAssertEqual(try DemoScript.load(from: URL(fileURLWithPath: firstCopy)).actions.count, 2)
        let validBytes = try Data(contentsOf: managed)
        try Data("bad JSON".utf8).write(to: managed)
        XCTAssertEqual(try command(["reload"]).0, 1)
        XCTAssertEqual(try command(["status"]).1.status?.actionCount, 4)
        try validBytes.write(to: managed)
        // Editing the managed copy is the explicit reload workflow.
        try JSONSerialization.data(withJSONObject: ["version": 1, "name": "Edited", "actions": [["type": "text", "value": "ABC"]]]).write(to: managed)
        XCTAssertEqual(try command(["reload"]).1.status?.actionCount, 3)
        try Data("bad JSON".utf8).write(to: file)
        XCTAssertEqual(try command(["load", file.path]).0, 1)
        XCTAssertEqual(try command(["status"]).1.status?.configurationPath, managed.path)
        XCTAssertEqual(try command(["load", root.appendingPathComponent("missing.json").path]).0, 1)
        XCTAssertEqual(try command(["status"]).1.status?.pid, pid)
        try FileManager.default.removeItem(at: file)
        XCTAssertEqual(try command(["stop"]).1.status?.state, "off")
        XCTAssertEqual(try command(["quit"]).1.status?.running, false)
        XCTAssertEqual(try command(["status"]).1.status?.running, false)
        let restarted = try command(["start"])
        XCTAssertEqual(restarted.1.status?.configurationPath, managed.path)
        XCTAssertEqual(restarted.1.status?.configurationName, "Edited")
        XCTAssertEqual(restarted.1.status?.actionCount, 3)
        XCTAssertEqual(restarted.1.status?.hotkey, "ctrl+option+k")
        XCTAssertNotEqual(restarted.1.status?.pid, pid)
    }
    func testDroppedSegmentedConfigurationAndAdvanceShortcutPersist() throws {
        let started = try command(["start"])
        XCTAssertEqual(started.0, 0, started.1.message)
        let paths = RuntimePaths(environment: ["CUETAP_HOME": root.appendingPathComponent("profile").path])
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("html-demo.json")
        let destination = paths.configurations.appendingPathComponent("dropped.json")
        try FileManager.default.copyItem(at: source, to: destination)
        try Data("broken".utf8).write(to: paths.configurations.appendingPathComponent("bad.json"))
        let listed = try XCTUnwrap(command(["config", "list"]).1.configurations)
        XCTAssertEqual(listed.first { $0.id == "dropped" }?.segmentCount, 3)
        XCTAssertNotNil(listed.first { $0.id == "bad" }?.error)
        let used = try command(["config", "use", "dropped"])
        XCTAssertEqual(used.0, 0, used.1.message)
        XCTAssertEqual(used.1.status?.segmentCount, 3)
        XCTAssertEqual(used.1.status?.segmentIndex, 1)
        XCTAssertEqual(used.1.status?.configurationPath, destination.resolvingSymlinksInPath().path)
        XCTAssertEqual(try command(["advance", "set", "alt+shift+click"]).1.status?.advanceShortcut, "option+shift+click")
        XCTAssertEqual(try command(["advance", "set", "click"]).0, 2)
        XCTAssertEqual(try command(["quit"]).0, 0)
        XCTAssertEqual(try command(["advance", "get"]).1.status?.advanceShortcut, "option+shift+click")
        let restarted = try command(["start"])
        XCTAssertEqual(restarted.1.status?.configurationPath, destination.resolvingSymlinksInPath().path)
        XCTAssertEqual(restarted.1.status?.advanceShortcut, "option+shift+click")
        XCTAssertEqual(restarted.1.status?.segmentCount, 3)
    }

    func testStartupMigratesLegacyExternalPathAndKeepsHotkey() throws {
        let source = root.appendingPathComponent("legacy demo.json")
        try FileManager.default.copyItem(at: ExampleFixture.url, to: source)
        let paths = RuntimePaths(environment: ["CUETAP_HOME": root.appendingPathComponent("profile").path])
        try paths.save(RuntimeSettings(configurationPath: source.path, hotkey: "ctrl+option+k"))
        let result = try command(["start"])
        XCTAssertEqual(result.0, 0, result.1.message)
        let copy = try XCTUnwrap(result.1.status?.configurationPath)
        XCTAssertNotEqual(copy, source.path)
        XCTAssertEqual(URL(fileURLWithPath: copy).deletingLastPathComponent().path, paths.configurations.path)
        XCTAssertEqual(try paths.read().configurationPath, copy)
        XCTAssertEqual(result.1.status?.hotkey, "ctrl+option+k")
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.log.path))
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try command(["quit"]).0, 0)
        let restarted = try command(["start"])
        XCTAssertEqual(restarted.0, 0, restarted.1.message)
        XCTAssertEqual(restarted.1.status?.configurationPath, copy)
        XCTAssertEqual(restarted.1.status?.actionCount, 38)
        XCTAssertEqual(restarted.1.status?.hotkey, "ctrl+option+k")
    }

    func testBundledDefaultSurvivesReplacementOfTheInstallation() throws {
        func install(_ name: String) throws -> URL {
            let folder = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let binary = folder.appendingPathComponent("cuetap")
            try FileManager.default.copyItem(at: executable, to: binary)
            return binary
        }
        let first = try install("version one")
        try FileManager.default.copyItem(at: ExampleFixture.url, to: first.deletingLastPathComponent().appendingPathComponent("html-demo.json"))
        let initial = try command(["start"], using: first)
        XCTAssertEqual(initial.0, 0, initial.1.message)
        let copy = try XCTUnwrap(initial.1.status?.configurationPath)
        XCTAssertEqual(try command(["quit"]).0, 0)
        try FileManager.default.removeItem(at: first.deletingLastPathComponent())
        // The upgraded installation has no bundled example. Existing user data must still work.
        let second = try install("version two")
        let next = try command(["start"], using: second)
        XCTAssertEqual(next.0, 0, next.1.message)
        XCTAssertEqual(next.1.status?.configurationPath, copy)
        XCTAssertEqual(next.1.status?.actionCount, 38)
        XCTAssertEqual(next.1.status?.executable, second.path)
    }
    func testJSONErrorsAndVersionAreMachineReadable() throws {
        XCTAssertEqual(try command(["version"]).1.version, "0.4.0")
        XCTAssertEqual(try command(["validate", ExampleFixture.url.path]).1.status?.actionCount, 38)
        XCTAssertEqual(try command(["hotkey", "set", "cmd+r"]).0, 2)
        XCTAssertEqual(try command(["reload"]).1.error?.code, "not_running")
        XCTAssertEqual(try command(["quit"]).0, 0)
    }

    func testConfigurationCommandsWorkByIDAndPreserveDescriptionAcrossRestart() throws {
        XCTAssertEqual(try command(["config", "list"]).1.configurations?.count, 0)
        let started = try command(["start", "--script", ExampleFixture.url.path])
        XCTAssertEqual(started.0, 0, started.1.message)
        let originalID = try XCTUnwrap(started.1.status?.configurationID)
        let originalName = try XCTUnwrap(started.1.status?.configurationName)
        let originalDescription = try XCTUnwrap(started.1.status?.configurationDescription)
        XCTAssertFalse(originalDescription.isEmpty)
        let source = root.appendingPathComponent("login.json")
        try JSONSerialization.data(withJSONObject: ["version": 1, "name": "Login", "description": "购物小程序的登录表单", "actions": [["type": "text", "value": "login()"]]]).write(to: source)
        let loaded = try command(["load", source.path])
        XCTAssertEqual(loaded.0, 0, loaded.1.message)
        let id = try XCTUnwrap(loaded.1.status?.configurationID)
        XCTAssertEqual(loaded.1.status?.configurationDescription, "购物小程序的登录表单")
        let renamed = try command(["config", "rename", id, originalName])
        XCTAssertEqual(renamed.1.status?.configurationID, id)
        XCTAssertEqual(renamed.1.status?.configurationName, originalName)
        XCTAssertEqual(try command(["config", "use", originalName]).1.error?.code, "ambiguous_configuration")
        let list = try XCTUnwrap(command(["config", "list"]).1.configurations)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.first { $0.id == id }?.description, "购物小程序的登录表单")
        XCTAssertTrue(list.first { $0.id == id }?.selected == true)
        XCTAssertEqual(try command(["config", "use", originalID]).1.status?.actionCount, 38)
        XCTAssertEqual(try command(["config", "rename", originalID, "Renamed HTML"]).1.status?.configurationName, "Renamed HTML")
        XCTAssertEqual(try command(["config", "remove", originalID]).1.error?.code, "configuration_in_use")
        XCTAssertEqual(try command(["quit"]).0, 0)
        XCTAssertEqual(try command(["config", "list"]).1.configurations?.count, 2)
        let destination = root.appendingPathComponent("export copy.json")
        XCTAssertEqual(try command(["config", "export", id, destination.path]).1.outputPath, destination.path)
        XCTAssertEqual(try DemoScript.load(from: destination).description, "购物小程序的登录表单")
        XCTAssertEqual(try command(["config", "export", id, destination.path]).1.error?.code, "destination_exists")
        XCTAssertEqual(try command(["config", "use", originalID]).1.error?.code, "not_running")
        let restarted = try command(["start"])
        XCTAssertEqual(restarted.1.status?.configurationID, originalID)
        XCTAssertEqual(restarted.1.status?.configurationName, "Renamed HTML")
        XCTAssertEqual(restarted.1.status?.configurationDescription, originalDescription)
        XCTAssertEqual(try command(["config", "remove", id]).0, 0)
        XCTAssertEqual(try command(["config", "list"]).1.configurations?.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }

    func testDoctorQueriesTheResidentWithoutRestartingOrChangingFiles() throws {
        let started = try command(["start", "--script", ExampleFixture.url.path])
        XCTAssertEqual(started.0, 0, started.1.message)
        let paths = RuntimePaths(environment: ["CUETAP_HOME": root.appendingPathComponent("profile").path])
        let saved = try Data(contentsOf: paths.settings)
        let configuration = URL(fileURLWithPath: try XCTUnwrap(started.1.status?.configurationPath))
        let data = try Data(contentsOf: configuration)
        let report = try command(["doctor"])
        XCTAssertEqual(report.0, 0, report.1.message)
        XCTAssertEqual(report.1.diagnostics?.permissionsScope, "resident")
        XCTAssertEqual(report.1.status?.pid, started.1.status?.pid)
        XCTAssertEqual(report.1.status?.state, "off")
        XCTAssertEqual(report.1.diagnostics?.logPath, paths.log.path)
        XCTAssertEqual(try Data(contentsOf: paths.settings), saved)
        XCTAssertEqual(try Data(contentsOf: configuration), data)
    }
}
