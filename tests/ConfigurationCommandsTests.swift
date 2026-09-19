import Foundation
import XCTest

final class ConfigurationCommandsTests: XCTestCase {
    private var root: URL!
    private var paths: RuntimePaths { RuntimePaths(environment: ["CUETAP_HOME": root.appendingPathComponent("profile").path]) }
    private var store: ConfigurationStore { ConfigurationStore(paths: paths) }
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap-library-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    private func importFile(_ filename: String, name: String = "Demo") throws -> URL {
        let source = root.appendingPathComponent(filename)
        let data = try JSONSerialization.data(withJSONObject: ["version": 1, "name": name, "description": "小程序首页代码", "actions": [["type": "text", "value": "A\n B"]]])
        try data.write(to: source)
        return try store.select(from: source, settings: paths.read()).url
    }

    func testRenameKeepsIDDescriptionAndActionsAndListShowsSelection() throws {
        let url = try importFile("demo.json")
        let before = try DemoScript.load(from: url)
        let id = try XCTUnwrap(store.id(for: url))
        let renamed = try store.rename(url, to: "New name")
        XCTAssertEqual(renamed.actions, before.actions)
        XCTAssertEqual(renamed.description, "小程序首页代码")
        XCTAssertEqual(store.id(for: url), id)
        XCTAssertEqual(try store.resolve(id).resolvingSymlinksInPath(), url.resolvingSymlinksInPath())
        XCTAssertEqual(try store.resolve("New name").resolvingSymlinksInPath(), url.resolvingSymlinksInPath())
        let list = try store.list(selectedPath: paths.read().configurationPath)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].id, id)
        XCTAssertEqual(list[0].name, "New name")
        XCTAssertEqual(list[0].description, "小程序首页代码")
        XCTAssertTrue(list[0].selected)
        XCTAssertThrowsError(try store.rename(url, to: "\n "))
        XCTAssertEqual(try DemoScript.load(from: url).name, "New name")
    }

    func testDuplicateNamesRequireIDsAndSelectorsCannotEscapeTheLibrary() throws {
        let a = try importFile("a.json")
        let b = try importFile("b.json")
        XCTAssertThrowsError(try store.resolve("Demo")) { XCTAssertEqual(($0 as? ControlError)?.code, "ambiguous_configuration") }
        XCTAssertEqual(try store.resolve("a").resolvingSymlinksInPath(), a.resolvingSymlinksInPath())
        XCTAssertEqual(try store.resolve("b").resolvingSymlinksInPath(), b.resolvingSymlinksInPath())
        for selector in ["../a", root.appendingPathComponent("a.json").path, "missing"] {
            XCTAssertThrowsError(try store.resolve(selector)) { XCTAssertEqual(($0 as? ControlError)?.code, "configuration_not_found") }
        }
    }

    func testExportDoesNotOverwriteAndSelectedConfigurationCannotBeRemoved() throws {
        let a = try importFile("a.json")
        let b = try importFile("b.json")
        let destination = root.appendingPathComponent("export.json")
        try store.export(a, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: a))
        XCTAssertThrowsError(try store.export(b, to: destination)) { XCTAssertEqual(($0 as? ControlError)?.code, "destination_exists") }
        XCTAssertThrowsError(try store.export(a, to: paths.configurations.appendingPathComponent("copy.json")))
        XCTAssertThrowsError(try store.remove(b, selectedPath: paths.read().configurationPath)) { XCTAssertEqual(($0 as? ControlError)?.code, "configuration_in_use") }
        try store.remove(a, selectedPath: paths.read().configurationPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("a.json").path))
    }
}
