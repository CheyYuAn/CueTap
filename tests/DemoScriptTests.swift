import Foundation
import XCTest

final class DemoScriptTests: XCTestCase {
    func testDescriptionSupportsUserLanguageAndLegacyFiles() throws {
        let data = Data(#"{"version":1,"name":"demo","description":"某微信小程序的登录表单代码","actions":[{"type":"text","value":"A"}]}"#.utf8)
        let script = try DemoScript.decode(data)
        XCTAssertEqual(script.description, "某微信小程序的登录表单代码")
        XCTAssertEqual(script.actions, [.character("A")])
        XCTAssertEqual(try decode(#"[{"type":"text","value":"A"}]"#).description, "")
    }
    func testDescriptionRejectsNonStringsAndNull() {
        for value in ["null", "7", "true", "[]", "{}"] {
            let json = "{\"version\":1,\"name\":\"demo\",\"description\":\(value),\"actions\":[{\"type\":\"text\",\"value\":\"A\"}]}"
            XCTAssertThrowsError(try DemoScript.decode(Data(json.utf8)))
        }
    }
    private func decode(_ entries: String) throws -> DemoScript {
        try DemoScript.decode(Data("{\"version\":1,\"name\":\"test\",\"actions\":\(entries)}".utf8))
    }

    func testTextAndRepeatedKeysExpandWithoutReordering() throws {
        let script = try decode(#"[{"type":"text","value":"Ab9={}\"\\"},{"type":"key","key":"left","count":2},{"type":"key","key":"right"},{"type":"key","key":"enter"},{"type":"key","key":"tab"}]"#)
        XCTAssertEqual(script.actions, "Ab9={}\"\\".map(DemoAction.character) + [.left, .left, .right, .enter, .tab])
        let controller = DemoController(actions: script.actions)
        _ = controller.handle(KeyboardInput(kind: .down, keyCode: 15, modifiers: .hotkey), frontmostPID: 1)
        _ = controller.handle(KeyboardInput(kind: .up, keyCode: 15), frontmostPID: 1)
        var output: [DemoAction] = []
        for _ in script.actions {
            if let action = controller.handle(KeyboardInput(kind: .down, keyCode: 0), frontmostPID: 1).action { output.append(action) }
            _ = controller.handle(KeyboardInput(kind: .up, keyCode: 0), frontmostPID: 1)
        }
        XCTAssertEqual(output, script.actions)
        XCTAssertEqual(controller.state, .complete)
    }

    func testBackspaceKeyExpandsAndUnknownKeysAreRejected() throws {
        let script = try decode(#"[{"type":"text","value":"ab"},{"type":"key","key":"backspace","count":2}]"#)
        XCTAssertEqual(script.actions, [.character("a"), .character("b"), .backspace, .backspace])
        XCTAssertThrowsError(try decode(#"[{"type":"key","key":"delete"}]"#)) { error in
            XCTAssertTrue("\(error)".contains("left, right, enter, tab and backspace"), "\(error)")
        }
    }

    func testNewlinesAndTabsPreserveExplicitWhitespace() throws {
        let script = try decode(#"[{"type":"text","value":"a\r\n  b\n\tc"}]"#)
        XCTAssertEqual(script.actions, [.character("a"), .enter, .character(" "), .character(" "), .character("b"), .enter, .tab, .character("c")])
    }

    func testEveryPrintableASCIICharacterIsSupported() throws {
        let characters = String((32...126).map { Character(UnicodeScalar($0)!) })
        let data = try JSONSerialization.data(withJSONObject: ["version": 1, "name": "ASCII", "actions": [["type": "text", "value": characters]]])
        XCTAssertEqual(try DemoScript.decode(data).actions, characters.map(DemoAction.character))
        XCTAssertEqual(USKeyboardLayout.stroke(for: "Z")?.keyCode, 6)
        XCTAssertEqual(USKeyboardLayout.stroke(for: "Z")?.shifted, true)
        XCTAssertEqual(USKeyboardLayout.stroke(for: "0")?.keyCode, 29)
        XCTAssertEqual(USKeyboardLayout.stroke(for: "{")?.keyCode, 33)
        XCTAssertEqual(USKeyboardLayout.stroke(for: "|")?.keyCode, 42)
    }

    func testInvalidEntriesFailAtTheirIndex() {
        let invalid = [
            #"{"type":"key","key":"left","count":0}"#,
            #"{"type":"key","key":"left","count":-1}"#,
            #"{"type":"key","key":"left","count":1.5}"#,
            #"{"type":"key","key":"left","count":true}"#,
            #"{"type":"key","key":"escape"}"#,
            #"{"type":"text","value":""}"#,
            #"{"type":"text","value":"hi","count":2}"#,
            #"{"type":"key","key":"enter","value":"hi"}"#,
            #"{"type":"paste","value":"hi"}"#,
            #"{"type":"text","vaule":"hi"}"#,
            #"{"type":"text","value":"中文"}"#,
            #"{"type":"text","value":"a\u0000b"}"#,
            #"{"type":"text","value":"a\rb"}"#,
            #"{"type":"key","key":"left","count":null}"#
        ]
        for entry in invalid {
            XCTAssertThrowsError(try decode("[\(entry)]"), entry) { error in
                XCTAssertTrue(String(describing: error).contains("actions[0]"), "\(error)")
            }
        }
    }

    func testInvalidDocumentIsRejected() {
        for json in ["{", "[]", #"{"version":2,"name":"test","actions":[]}"#,
                     #"{"version":1,"name":" ","actions":[]}"#,
                     #"{"version":1,"name":"test","actions":[]}"#,
                     #"{"version":1,"actions":[]}"#,
                     #"{"version":1,"name":"test","actions":[],"extra":1}"#] {
            XCTAssertThrowsError(try DemoScript.decode(Data(json.utf8)))
        }
    }

    func testSizeAndExpansionLimitsAreCheckedBeforeAllocation() throws {
        XCTAssertThrowsError(try DemoScript.decode(Data(repeating: 32, count: DemoScript.maximumBytes + 1)))
        XCTAssertEqual(try decode(#"[{"type":"key","key":"left","count":100000}]"#).actions.count, 100_000)
        XCTAssertThrowsError(try decode(#"[{"type":"key","key":"left","count":100000},{"type":"text","value":"x"}]"#))
        XCTAssertThrowsError(try decode(#"[{"type":"key","key":"left","count":9223372036854775807}]"#))
    }
}
