import Foundation
import XCTest

final class KeystrokeCompilerTests: XCTestCase {
    private func compile(_ text: String, language: String = "cpp") throws -> KeystrokeCompiler.Segment {
        try KeystrokeCompiler(profile: try CompileFixture.profile(language)).compile(text, name: "test")
    }

    private func replay(_ segment: KeystrokeCompiler.Segment, language: String) throws -> String {
        var editor = VirtualEditor(profile: try CompileFixture.profile(language))
        for entry in segment.entries {
            switch entry {
            case .text(let value): for character in value { editor.apply(.character(character)) }
            case .key(let key, let count):
                let action: DemoAction = [ "left": .left, "right": .right, "enter": .enter, "tab": .tab, "backspace": .backspace][key]!
                for _ in 0..<count { editor.apply(action) }
            }
        }
        return editor.text
    }

    func testCGuessNumberCompilesAndReplaysToTheTarget() throws {
        let target = try CompileFixture.text("c-guess-number.c")
        let segment = try compile(target)
        XCTAssertTrue(segment.droppedTrailingNewline)
        XCTAssertEqual(segment.lineCount, 10)
        XCTAssertEqual(try replay(segment, language: "cpp") + "\n", target)
        let entries = segment.entries
        XCTAssertTrue(entries.contains(.text("{}")), "braces are typed as a pair")
        XCTAssertTrue(entries.contains(.text("\"\"")), "quotes are typed as a pair")
        XCTAssertFalse(entries.contains { if case .text(let value) = $0 { return value.contains("\n") }; return false }, "line breaks are enter keys")
        XCTAssertEqual(entries.filter { $0 == .key("tab", 1) }.count, 1, "one tab restores the indentation the pending brace pulled back")
        XCTAssertTrue(entries.contains(.key("right", 1)), "the pending brace before while is stepped over")
        XCTAssertFalse(entries.contains(.key("backspace", 1)))
        XCTAssertEqual(segment.actionCount, 371, "the same count as the hand-written configuration this replaces")
        XCTAssertEqual(entries.last, .text("; return 0;"), "the closing brace of main is already in place, so typing stops")
        XCTAssertTrue(entries.contains(.text("; int secret = rand() % 100 + 1, guess, n = 0;")), "empty pairs are typed straight through")
    }

    func testPythonGuessNumberCompilesWithBackspaceBeforeElifAndElse() throws {
        let target = try CompileFixture.text("python-guess-number.py")
        let segment = try compile(target, language: "python")
        XCTAssertEqual(try replay(segment, language: "python") + "\n", target)
        XCTAssertEqual(segment.entries.filter { $0 == .key("backspace", 1) }.count, 2)
        XCTAssertFalse(segment.entries.contains { if case .key("tab", _) = $0 { return true }; return false })
        let expectedStart: [ActionEntry] = [.text("import random"), .key("enter", 2), .text("secret = random.randint"), .text("()"), .key("left", 1), .text("1, 100"), .key("right", 1), .key("enter", 1)]
        XCTAssertEqual(Array(segment.entries.prefix(expectedStart.count)), expectedStart)
    }

    func testNestedCallExpandsLikeTheDocumentedExample() throws {
        let segment = try compile("guess = int(input(\"Guess: \"))", language: "python")
        XCTAssertEqual(segment.entries, [.text("guess = int"), .text("()"), .key("left", 1), .text("input"), .text("()"), .key("left", 1),
                                         .text("\"\""), .key("left", 1), .text("Guess: "), .key("right", 3)])
    }

    func testClosingBraceOnItsOwnLineIsWalkedOverNotTyped() throws {
        let segment = try compile("int main(void) {\n    return 0;\n}")
        XCTAssertEqual(segment.entries, [.text("int main"), .text("()"), .key("left", 1), .text("void"), .key("right", 1), .text(" "), .text("{}"), .key("left", 1),
                                         .key("enter", 1), .text("return 0;")], "the brace is already on its own line, so typing stops before it")
    }

    func testUnbalancedBracketsInsideStringsAndCommentsAreTypedLiterally() throws {
        let segment = try compile("printf(\"}\"); // don't (\nint x = 1;")
        XCTAssertEqual(try replay(segment, language: "cpp"), "printf(\"}\"); // don't (\nint x = 1;")
        XCTAssertTrue(segment.entries.contains(.text("}")))
        XCTAssertTrue(segment.entries.contains(.text("; // don't (")))
    }

    func testBalancedBracketsInsideStringsArePairsButNeverPairWithCode() throws {
        let fString = try compile("print(f\"It took {guesses} tries\")", language: "python")
        XCTAssertEqual(fString.entries, [.text("print"), .text("()"), .key("left", 1), .text("f"), .text("\"\""), .key("left", 1), .text("It took "),
                                         .text("{}"), .key("left", 1), .text("guesses"), .key("right", 1), .text(" tries"), .key("right", 2)])
        let crossing = try compile("f(\"(\") + g(\")\")")
        XCTAssertEqual(try replay(crossing, language: "cpp"), "f(\"(\") + g(\")\")")
        XCTAssertTrue(crossing.entries.contains(.text("(")), "a lone bracket inside a string stays literal")
    }

    func testUnmatchedClosersAreTypedAndUnterminatedQuotesTooAndTargetIsReproduced() throws {
        let segment = try compile("x = a) + b\ns = 'it", language: "python")
        XCTAssertEqual(try replay(segment, language: "python"), "x = a) + b\ns = 'it")
        XCTAssertEqual(segment.entries, [.text("x = a) + b"), .key("enter", 1), .text("s = 'it")])
    }

    func testNonASCIIAndInlineTabsAreRejectedWithPositions() throws {
        XCTAssertThrowsError(try compile("printf(\"猜 1-100：\");")) { error in
            XCTAssertEqual((error as? ControlError)?.code, "unsupported_character")
            XCTAssertTrue(String(describing: error).contains("line 1 column 9"), String(describing: error))
            XCTAssertTrue(String(describing: error).contains("U+FF1A"))
        }
        XCTAssertThrowsError(try compile("int\tx;")) { error in XCTAssertEqual((error as? ControlError)?.code, "unsupported_tab") }
    }

    func testTabIndentedTargetNeedsTheTabsProfile() throws {
        XCTAssertThrowsError(try compile("if (x) {\n\ty;\n}")) { error in
            XCTAssertEqual((error as? ControlError)?.code, "compile_failed")
            XCTAssertTrue(String(describing: error).contains("--tabs"))
        }
        let profile = try CompileFixture.profile("cpp", tabSize: 4, insertSpaces: false)
        let segment = try KeystrokeCompiler(profile: profile).compile("if (x) {\n\ty;\n}", name: "tabs")
        XCTAssertEqual(segment.entries, [.text("if "), .text("()"), .key("left", 1), .text("x"), .key("right", 1), .text(" "), .text("{}"), .key("left", 1), .key("enter", 1), .text("y;")])
    }

    func testBlankLinesInsideBlocksAndDeeperTargetIndentationUseEditorBehaviour() throws {
        let target = "int main(void) {\n    int x = 1;\n\n    int y = 2;\n        int z = 3;\n    return x;\n}"
        let segment = try compile(target)
        XCTAssertEqual(try replay(segment, language: "cpp"), target)
        XCTAssertTrue(segment.entries.contains(.key("tab", 1)))
        XCTAssertTrue(segment.entries.contains(.key("backspace", 1)))
    }

    func testVueCounterCompilesToTheHandWrittenSequence() throws {
        let target = try CompileFixture.text("vue-counter.vue")
        let segment = try compile(target, language: "vue")
        XCTAssertEqual(try replay(segment, language: "vue") + "\n", target)
        XCTAssertEqual(segment.actionCount, 307, "the same count as the hand-written configuration this replaces")
        let expectedStart: [ActionEntry] = [
            .text("<template></template>"), .key("left", 11), .key("enter", 1),
            .text("<div></div>"), .key("left", 7), .text(" class="), .text("\"\""), .key("left", 1), .text("counter"), .key("right", 2), .key("enter", 1),
            .text("<p></p>"), .key("left", 4), .text("Count: "), .text("{}"), .key("left", 1), .text("{}"), .key("left", 1), .text(" count "), .key("right", 2),
            .text(", Double: "), .text("{}"), .key("left", 1), .text("{}"), .key("left", 1), .text(" double "), .key("right", 6), .key("enter", 1),
            .text("<button></button>"), .key("left", 10), .text(" @click="), .text("\"\""), .key("left", 1), .text("count++"), .key("right", 2), .text("+1"), .key("right", 9), .key("enter", 1),
        ]
        XCTAssertEqual(Array(segment.entries.prefix(expectedStart.count)), expectedStart)
        XCTAssertEqual(segment.entries.last, .text("Reset"), "the closing tags are already in place, so typing stops")
    }

    func testHTMLLeafVoidAndCommentedTags() throws {
        let target = "<ul>\n    <li>a</li>\n    <br>\n    <!-- <b>x</b> -->\n    <img src=\"a.png\" />\n</ul>"
        let segment = try compile(target, language: "html")
        XCTAssertEqual(try replay(segment, language: "html"), target)
        XCTAssertEqual(Array(segment.entries.prefix(6)), [.text("<ul></ul>"), .key("left", 5), .key("enter", 1), .text("<li></li>"), .key("left", 5), .text("a")])
        XCTAssertTrue(segment.entries.contains(.text("<br>")), "void elements are plain text")
        XCTAssertTrue(segment.entries.contains { if case .text(let value) = $0 { return value.contains("<!-- <b>x</b> -->") }; return false }, "comments are plain text")
        XCTAssertTrue(segment.entries.contains(.text("<img src=")), "self-closing tags are plain text with paired quotes")
        XCTAssertEqual(segment.entries.last, .text(" />"))
    }

    func testJSXExpressionAttributesKeepTheirArrows() throws {
        let profile = EditorProfile(name: "vscode-html", rules: try CompileFixture.profile("html").rules, rulesSource: "fixture", tags: true, languageId: "html")
        let target = "<button onClick={() => setCount(count + 1)}>+1</button>"
        let segment = try KeystrokeCompiler(profile: profile).compile(target, name: "jsx")
        XCTAssertEqual(segment.entries, [.text("<button></button>"), .key("left", 10), .text(" onClick="), .text("{}"), .key("left", 1), .text("() => setCount"),
                                         .text("()"), .key("left", 1), .text("count + 1"), .key("right", 3), .text("+1"), .key("right", 9)])
    }

    func testUnmatchedTagsStayLiteralAndMultilineTagsAreStillPairs() throws {
        // A closing tag typed on its own line is outdented by the editor's decreaseIndentPattern, so the
        // target has it at the left margin; a tag broken across lines is still written as a pair, with
        // Enter and Tab inside the opening tag.
        let target = "<div>\n</span>\n    <a\n        href=\"x\"\n    >y</a>\n</div>"
        let segment = try compile(target, language: "html")
        XCTAssertEqual(try replay(segment, language: "html"), target)
        XCTAssertTrue(segment.entries.contains(.text("</span>")))
        let start = try XCTUnwrap(segment.entries.firstIndex(of: .text("<a></a>")))
        XCTAssertEqual(Array(segment.entries[start...]), [.text("<a></a>"), .key("left", 5), .key("enter", 1), .key("tab", 1), .text("href="), .text("\"\""), .key("left", 1), .text("x"), .key("right", 1),
                                                          .key("enter", 1), .key("backspace", 1), .key("right", 1), .text("y")], "the closing tags that remain are already in place")
        XCTAssertThrowsError(try compile("<div>\n    </span>\n</div>", language: "html")) { error in
            XCTAssertEqual((error as? ControlError)?.code, "compile_failed", "an indented stray closing tag cannot be produced because the editor outdents it")
        }
    }

    func testScriptBlocksCompileWithTheEmbeddedLanguageRules() throws {
        var profile = try CompileFixture.profile("html")
        profile.embedded = ["script": try CompileFixture.profile("cpp").rules]
        let target = "<script>\n    function f(a) {\n        return a + 1; // (not a tag) <b>\n    }\n</script>\n<p>x</p>"
        let segment = try KeystrokeCompiler(profile: profile).compile(target, name: "embedded")
        var editor = VirtualEditor(profile: profile)
        for entry in segment.entries {
            switch entry {
            case .text(let value): for character in value { editor.apply(.character(character)) }
            case .key(let key, let count):
                let action: DemoAction = ["left": .left, "right": .right, "enter": .enter, "tab": .tab, "backspace": .backspace][key]!
                for _ in 0..<count { editor.apply(action) }
            }
        }
        XCTAssertEqual(editor.text, target)
        XCTAssertTrue(segment.entries.contains(.text("function f")), "script content is code, not tags")
        XCTAssertTrue(segment.entries.contains(.text("return a + 1; // (not a tag) <b>")), "a line comment inside script is typed as is")
        XCTAssertEqual(segment.entries.first, .text("<script></script>"))
    }

    func testRenderedConfigurationDecodesAndKeepsTheHandWrittenLayout() throws {
        let segment = try compile("f(\"a\");")
        let rendered = ConfigurationWriter.render(name: "Demo", description: "描述 \"x\"", segments: [(name: "one", description: "", entries: segment.entries)])
        let script = try DemoScript.decode(Data(rendered.utf8))
        XCTAssertEqual(script.name, "Demo")
        XCTAssertEqual(script.description, "描述 \"x\"")
        XCTAssertEqual(script.actions.count, segment.actionCount)
        XCTAssertTrue(rendered.contains("        { \"type\": \"text\", \"value\": \"()\" },\n        { \"type\": \"key\", \"key\": \"left\" },"))
        XCTAssertTrue(rendered.contains("\"count\": 2"))
    }
}
