import Foundation
import XCTest

final class CompileCLITests: XCTestCase {
    private var folder: URL!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap compile test \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }

    private func run(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("cuetap")
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment
        environment["CUETAP_HOME"] = folder.appendingPathComponent("profile").path
        process.environment = environment
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: output, as: UTF8.self))
    }

    private func json(_ output: String) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any], output)
    }

    func testCompileWritesAValidConfigurationAndReportsSegments() throws {
        let rules = CompileFixture.url("vscode-cpp-language-configuration.json").path
        let output = folder.appendingPathComponent("demo.json").path
        let result = try run(["compile", "--rules", rules, "--output", output, "--name", "C Demo", "--description", "猜数字", CompileFixture.url("c-guess-number.c").path, "--json"])
        XCTAssertEqual(result.status, 0, result.output)
        let response = try json(result.output)
        XCTAssertEqual(response["ok"] as? Bool, true)
        XCTAssertEqual(response["outputPath"] as? String, output)
        let report = try XCTUnwrap(response["compile"] as? [String: Any])
        XCTAssertEqual(report["profile"] as? String, "custom")
        XCTAssertEqual(report["actionCount"] as? Int, 371)
        let segments = try XCTUnwrap(report["segments"] as? [[String: Any]])
        XCTAssertEqual(segments.first?["name"] as? String, "c-guess-number")
        let script = try DemoScript.load(from: URL(fileURLWithPath: output))
        XCTAssertEqual(script.name, "C Demo")
        XCTAssertEqual(script.description, "猜数字")
        XCTAssertEqual(script.segments.count, 1)
        let validate = try run(["validate", output, "--json"])
        XCTAssertEqual(validate.status, 0, validate.output)
    }

    func testCompileRefusesToOverwriteWithoutForceAndRejectsUnknownProfiles() throws {
        let rules = CompileFixture.url("vscode-python-language-configuration.json").path
        let output = folder.appendingPathComponent("demo.json").path
        try Data("{}".utf8).write(to: URL(fileURLWithPath: output))
        let refused = try run(["compile", "--rules", rules, "--output", output, CompileFixture.url("python-guess-number.py").path, "--json"])
        XCTAssertEqual(refused.status, 1)
        XCTAssertEqual((try json(refused.output)["error"] as? [String: Any])?["code"] as? String, "output_exists")
        let forced = try run(["compile", "--rules", rules, "--output", output, "--force", CompileFixture.url("python-guess-number.py").path, "--json"])
        XCTAssertEqual(forced.status, 0, forced.output)
        XCTAssertEqual(try json(forced.output)["ok"] as? Bool, true)
        let unknown = try run(["compile", "--profile", "nano-c", "--output", folder.appendingPathComponent("x.json").path, output, "--json"])
        XCTAssertEqual(unknown.status, 1)
        XCTAssertEqual((try json(unknown.output)["error"] as? [String: Any])?["code"] as? String, "profile_not_found")
        let usage = try run(["compile", "--json"])
        XCTAssertEqual(usage.status, 2)
    }

    func testCompileWithTagRulesAndSettingsReport() throws {
        let output = folder.appendingPathComponent("vue.json").path
        let result = try run(["compile", "--rules", CompileFixture.url("vscode-vue-language-configuration.json").path, "--tags", "--output", output, CompileFixture.url("vue-counter.vue").path, "--json"])
        XCTAssertEqual(result.status, 0, result.output)
        let report = try XCTUnwrap(try json(result.output)["compile"] as? [String: Any])
        XCTAssertEqual(report["actionCount"] as? Int, 307)
        XCTAssertEqual(report["tags"] as? Bool, true)
        XCTAssertNotNil(report["settings"] as? [[String: Any]], "custom profiles still carry the settings array, empty or not")
        XCTAssertEqual(try DemoScript.load(from: URL(fileURLWithPath: output)).actions.count, 307)
    }

    func testEachTargetBecomesOneSegmentInOrder() throws {
        let rules = CompileFixture.url("vscode-cpp-language-configuration.json").path
        let first = folder.appendingPathComponent("header.c"), second = folder.appendingPathComponent("body.c")
        try "int x;\n".write(to: first, atomically: true, encoding: .utf8)
        try "int main(void) {\n    return x;\n}\n".write(to: second, atomically: true, encoding: .utf8)
        let output = folder.appendingPathComponent("two.json").path
        let result = try run(["compile", "--rules", rules, "--output", output, "--name", "Two", first.path, second.path, "--json"])
        XCTAssertEqual(result.status, 0, result.output)
        let report = try XCTUnwrap(try json(result.output)["compile"] as? [String: Any])
        let segments = try XCTUnwrap(report["segments"] as? [[String: Any]])
        XCTAssertEqual(segments.map { $0["name"] as? String }, ["header", "body"])
        XCTAssertEqual(segments.map { $0["lines"] as? Int }, [1, 3])
        let script = try DemoScript.load(from: URL(fileURLWithPath: output))
        XCTAssertEqual(script.name, "Two")
        XCTAssertEqual(script.segments.map(\.name), ["header", "body"])
        XCTAssertEqual(script.actions.count, report["actionCount"] as? Int)
        XCTAssertEqual(script.segments[0].actions, "int x;".map(DemoAction.character))
    }

    func testCompileReportsUnsupportedCharacters() throws {
        let target = folder.appendingPathComponent("chinese.c")
        try "printf(\"猜\");\n".write(to: target, atomically: true, encoding: .utf8)
        let result = try run(["compile", "--rules", CompileFixture.url("vscode-cpp-language-configuration.json").path, "--output", folder.appendingPathComponent("out.json").path, target.path, "--json"])
        XCTAssertEqual(result.status, 1)
        let error = try XCTUnwrap(try json(result.output)["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? String, "unsupported_character")
        XCTAssertTrue((error["message"] as? String ?? "").contains("line 1 column 9"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("out.json").path))
    }

    func testDiffReportsTheFirstDifferenceAndExitsOneOnMismatch() throws {
        let expected = folder.appendingPathComponent("expected.c"), actual = folder.appendingPathComponent("actual.c")
        try "int x;\n    y;\n}\n".write(to: expected, atomically: true, encoding: .utf8)
        try "int x;\n    y;\n}".write(to: actual, atomically: true, encoding: .utf8)
        let same = try run(["diff", expected.path, actual.path, "--json"])
        XCTAssertEqual(same.status, 0, same.output)
        let comparison = try XCTUnwrap(try json(same.output)["comparison"] as? [String: Any])
        XCTAssertEqual(comparison["identical"] as? Bool, true)
        XCTAssertEqual(comparison["trailingNewline"] as? String, "expected ends with a newline, actual does not")
        try "int x;\ny;\n}\n".write(to: actual, atomically: true, encoding: .utf8)
        let different = try run(["diff", expected.path, actual.path, "--json"])
        XCTAssertEqual(different.status, 1)
        let response = try json(different.output)
        XCTAssertEqual((response["error"] as? [String: Any])?["code"] as? String, "text_mismatch")
        let mismatch = try XCTUnwrap(response["comparison"] as? [String: Any])
        XCTAssertEqual(mismatch["line"] as? Int, 2)
        XCTAssertEqual(mismatch["column"] as? Int, 1)
        XCTAssertEqual(mismatch["expected"] as? String, "    y;")
        let plain = try run(["diff", expected.path, actual.path])
        XCTAssertEqual(plain.status, 1)
        XCTAssertTrue(plain.output.contains("Expected:     y;"), plain.output)
        XCTAssertEqual(try run(["diff", expected.path]).status, 2)
    }
}
