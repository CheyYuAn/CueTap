import Foundation
import XCTest

final class ConfigurationStoreTests: XCTestCase {
    private var root: URL!
    private var paths: RuntimePaths { RuntimePaths(environment: ["CUETAP_HOME": root.appendingPathComponent("profile").path]) }
    private var store: ConfigurationStore { ConfigurationStore(paths: paths) }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func write(_ text: String, to file: URL) throws {
        try JSONSerialization.data(withJSONObject: ["version": 1, "name": "User Demo", "actions": [["type": "text", "value": text]]])
            .write(to: file)
    }
    private func entries() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: paths.configurations.path).sorted()
    }

    func testImportedBytesSurviveSourceChangesAndDeletionWithPrivatePermissions() throws {
        let source = root.appendingPathComponent("user demo.json")
        try write("<div>\n  hello</div>", to: source)
        let snapshot = try DemoScript.readFile(from: source)
        try write("changed after validation", to: source)
        let selected = try store.select(snapshot, from: source, settings: RuntimeSettings(hotkey: "ctrl+option+k"))
        XCTAssertEqual(try Data(contentsOf: selected.url), snapshot.data)
        XCTAssertEqual(selected.script.actions, snapshot.script.actions)
        XCTAssertEqual(try DemoScript.load(from: source).actions.count, 24)
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try DemoScript.load(from: selected.url).actions, snapshot.script.actions)
        XCTAssertEqual(try paths.read().configurationPath, selected.url.path)
        XCTAssertEqual(try paths.read().hotkey, "ctrl+option+k")
        for url in [paths.directory, paths.configurations, paths.settings, selected.url] {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let expected = [paths.directory, paths.configurations].contains(url) ? 0o700 : 0o600
            XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, expected)
        }
    }

    func testSameNameImportsNeverOverwriteAndIdenticalImportsReuseExistingCopy() throws {
        let first = root.appendingPathComponent("demo.json")
        let other = root.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let second = other.appendingPathComponent("demo.json")
        try write("A", to: first)
        try write("BB", to: second)
        let one = try store.select(from: first, settings: RuntimeSettings())
        let two = try store.select(from: second, settings: one.settings)
        XCTAssertNotEqual(one.url, two.url)
        XCTAssertEqual(try DemoScript.load(from: one.url).actions, [.character("A")])
        XCTAssertEqual(try DemoScript.load(from: two.url).actions, [.character("B"), .character("B")])
        let repeated = try store.select(from: second, settings: two.settings)
        XCTAssertEqual(repeated.url, two.url)
        XCTAssertEqual(try entries().count, 2)
    }

    func testSelectingManagedCopyUsesItsEditsWithoutMakingAnotherCopy() throws {
        let source = root.appendingPathComponent("demo.json")
        try write("A", to: source)
        let first = try store.select(from: source, settings: RuntimeSettings())
        try write("BBB", to: first.url)
        let next = try store.select(from: first.url, settings: first.settings)
        XCTAssertEqual(next.url.resolvingSymlinksInPath(), first.url.resolvingSymlinksInPath())
        XCTAssertEqual(next.script.actions.count, 3)
        XCTAssertEqual(try entries().count, 1)
        XCTAssertEqual(try DemoScript.load(from: source).actions.count, 1)
    }

    func testInvalidMissingAndOversizedImportsLeaveCurrentSelectionUntouched() throws {
        let source = root.appendingPathComponent("demo.json")
        try write("A", to: source)
        let selected = try store.select(from: source, settings: RuntimeSettings())
        let saved = try Data(contentsOf: paths.settings)
        let missing = root.appendingPathComponent("missing.json")
        XCTAssertThrowsError(try store.select(from: missing, settings: selected.settings))
        try Data("invalid JSON".utf8).write(to: source)
        XCTAssertThrowsError(try store.select(from: source, settings: selected.settings))
        try Data(repeating: 0x20, count: DemoScript.maximumBytes + 1).write(to: source)
        XCTAssertThrowsError(try store.select(from: source, settings: selected.settings))
        XCTAssertEqual(try Data(contentsOf: paths.settings), saved)
        XCTAssertEqual(try DemoScript.load(from: selected.url).actions.count, 1)
        XCTAssertEqual(try entries().count, 1)
    }

    func testSettingsWriteFailureRemovesNewCopyAndPreservesExistingConfiguration() throws {
        let source = root.appendingPathComponent("demo.json")
        try write("A", to: source)
        let selected = try store.select(from: source, settings: RuntimeSettings())
        let before = try entries()
        let savedSettings = root.appendingPathComponent("saved-settings.json")
        try FileManager.default.moveItem(at: paths.settings, to: savedSettings)
        try FileManager.default.createDirectory(at: paths.settings, withIntermediateDirectories: false)
        try write("BB", to: source)
        XCTAssertThrowsError(try store.select(from: source, settings: selected.settings))
        XCTAssertEqual(try entries(), before)
        XCTAssertEqual(try DemoScript.load(from: selected.url).actions.count, 1)
        try FileManager.default.removeItem(at: paths.settings)
        try FileManager.default.moveItem(at: savedSettings, to: paths.settings)
        XCTAssertEqual(try paths.read().configurationPath, selected.url.path)
    }

    func testSymlinkToExternalFileIsImportedAsAnIndependentRegularFile() throws {
        let source = root.appendingPathComponent("source.json")
        try write("A", to: source)
        try paths.prepareConfigurations()
        let link = paths.configurations.appendingPathComponent("linked.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        let selected = try store.select(from: link, settings: RuntimeSettings())
        XCTAssertNotEqual(selected.url, link)
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try DemoScript.load(from: selected.url).actions.count, 1)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: selected.url.path)[.type] as? FileAttributeType, .typeRegular)
    }
}
