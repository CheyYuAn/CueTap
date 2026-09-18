import Foundation
import XCTest

final class CommandOptionsTests: XCTestCase {
    private let executable = URL(fileURLWithPath: "/example/build/cuetap")
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
