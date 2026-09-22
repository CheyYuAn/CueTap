import Foundation
import XCTest

final class CommandOptionsTests: XCTestCase {
    private let executable = URL(fileURLWithPath: "/example/build/cuetap")
    func testConfigurationCommandsAndDoctorParse() throws {
        for args in [["list"], ["use", "demo"], ["rename", "demo", "New Name"], ["export", "demo", "output file.json"], ["remove", "demo"]] {
            let options = try CommandOptions(arguments: ["config"] + args + ["--json"], executableURL: executable)
            XCTAssertEqual(options.mode, .config)
            XCTAssertEqual(options.configuration?.operation.rawValue, args[0])
        }
        let export = try CommandOptions(arguments: ["config", "export", "demo", "~/demo.json"], executableURL: executable)
        XCTAssertEqual(export.configuration?.value, NSHomeDirectory() + "/demo.json")
        XCTAssertEqual(try CommandOptions(arguments: ["doctor", "--json"], executableURL: executable).mode, .doctor)
    }
    func testInvalidConfigurationCommandArgumentsFail() {
        for args in [["config"], ["config", "delete", "x"], ["config", "list", "x"], ["config", "use"], ["config", "rename", "a", " "], ["config", "export", "a"], ["doctor", "--script", "x"]] {
            XCTAssertThrowsError(try CommandOptions(arguments: args, executableURL: executable))
        }
    }
    func testDefaultIsBesideExecutableNotWorkingDirectory() throws {
        let options = try CommandOptions(arguments: [], executableURL: executable)
        XCTAssertEqual(options.mode, .run)
        XCTAssertEqual(options.scriptURL.path, "/example/build/html-demo.json")
    }
    func testExplicitPathAndValidateInEitherOrder() throws {
        for args in [["--script", "/some folder/demo.json", "--validate"], ["--validate", "--script", "/some folder/demo.json"]] {
            let options = try CommandOptions(arguments: args, executableURL: executable)
            XCTAssertEqual(options.mode, .validate)
            XCTAssertEqual(options.scriptURL.path, "/some folder/demo.json")
        }
        let relative = try CommandOptions(arguments: ["--script", "example.json"], executableURL: executable)
        XCTAssertEqual(relative.scriptURL.path, URL(fileURLWithPath: "example.json").path)
        let tilde = try CommandOptions(arguments: ["--script", "~/example.json"], executableURL: executable)
        XCTAssertEqual(tilde.scriptURL.path, NSHomeDirectory() + "/example.json")
    }
    func testInvalidArgumentsFail() {
        for args in [["--script"], ["--script", ""], ["--script", "--validate"], ["--script", "a", "--script", "b"], ["--help", "--check"], ["--validate", "--validate"], ["--check", "--script", "a"], ["file.json"], ["--unknown"]] {
            XCTAssertThrowsError(try CommandOptions(arguments: args, executableURL: executable))
        }
    }
}

extension CommandOptionsTests {
    func testAgentCommandsParseWithJSONInEitherPosition() throws {
        for args in [["--json", "status"], ["status", "--json"]] {
            let value = try CommandOptions(arguments: args, executableURL: executable)
            XCTAssertEqual(value.mode, .status)
            XCTAssertTrue(value.json)
        }
        let load = try CommandOptions(arguments: ["load", "/a b/demo.json", "--json"], executableURL: executable)
        XCTAssertEqual(load.scriptURL.path, "/a b/demo.json")
        XCTAssertEqual(load.mode, .load)
        let hotkey = try CommandOptions(arguments: ["hotkey", "set", "ctrl+alt+k"], executableURL: executable)
        XCTAssertEqual(hotkey.hotkey, "ctrl+option+k")
    }
    func testDiffTakesOneOrMorePairs() throws {
        let executable = URL(fileURLWithPath: "/tmp/cuetap")
        let single = try CommandOptions(arguments: ["diff", "a.c", "b.c", "--json"], executableURL: executable)
        XCTAssertEqual(single.mode, .diff)
        XCTAssertEqual(single.diffPairs.map { $0.expected + ">" + $0.actual }, ["a.c>b.c"])
        let double = try CommandOptions(arguments: ["diff", "a.c", "b.c", "c.py", "d.py"], executableURL: executable)
        XCTAssertEqual(double.diffPairs.map { $0.expected + ">" + $0.actual }, ["a.c>b.c", "c.py>d.py"])
        XCTAssertThrowsError(try CommandOptions(arguments: ["diff", "a.c"], executableURL: executable))
        XCTAssertThrowsError(try CommandOptions(arguments: ["diff", "a.c", "b.c", "c.py"], executableURL: executable))
        XCTAssertThrowsError(try CommandOptions(arguments: ["diff", "a.c", "--force"], executableURL: executable))
    }

    func testProfilesParsesAndRejectsArguments() throws {
        let options = try CommandOptions(arguments: ["profiles", "--json"], executableURL: URL(fileURLWithPath: "/tmp/cuetap"))
        XCTAssertEqual(options.mode, .profiles)
        XCTAssertTrue(options.json)
        XCTAssertThrowsError(try CommandOptions(arguments: ["profiles", "extra"], executableURL: URL(fileURLWithPath: "/tmp/cuetap")))
    }

    func testUnexpectedAgentArgumentsAreRejected() {
        for args in [["status", "extra"], ["load"], ["reload", "--script", "a"], ["hotkey"], ["hotkey", "get", "extra"], ["start", "--json", "--json"], ["serve", "--json"]] {
            XCTAssertThrowsError(try CommandOptions(arguments: args, executableURL: executable))
        }
    }
}
