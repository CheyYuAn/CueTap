import Foundation
import XCTest

final class VirtualEditorTests: XCTestCase {
    private func editor(_ language: String) throws -> VirtualEditor { VirtualEditor(profile: try CompileFixture.profile(language)) }

    private func type(_ text: String, into editor: inout VirtualEditor) {
        for character in text { editor.apply(character == "\n" ? .enter : .character(character)) }
    }

    func testEnterBetweenBracesExpandsToThreeLines() throws {
        var editor = try self.editor("cpp")
        type("int main(void) {}", into: &editor)
        editor.apply(.left)
        editor.apply(.enter)
        XCTAssertEqual(editor.lines, ["int main(void) {", "    ", "}"])
        XCTAssertEqual(editor.row, 1)
        XCTAssertEqual(editor.column, 4)
    }

    func testEnterBeforePendingBraceIsPulledBackOneLevel() throws {
        var editor = try self.editor("cpp")
        type("int main(void) {}", into: &editor)
        editor.apply(.left)
        editor.apply(.enter)
        type("do {}", into: &editor)
        editor.apply(.left)
        type(" printf(\"x\"); n++;", into: &editor)
        editor.apply(.enter)
        XCTAssertEqual(editor.lines[2], "    }")
        XCTAssertEqual(editor.column, 4, "the increase for the open brace and the decrease for the pending close brace cancel out")
        editor.apply(.tab)
        XCTAssertEqual(editor.lines[2], "        }")
        XCTAssertEqual(editor.column, 8)
        type("if (x) y;", into: &editor)
        editor.apply(.enter)
        XCTAssertEqual(editor.lines[3], "    }")
        XCTAssertEqual(editor.beforeCursor, "    ")
        editor.apply(.right)
        type(" while (x);", into: &editor)
        editor.apply(.enter)
        XCTAssertEqual(editor.lines, ["int main(void) {", "    do { printf(\"x\"); n++;", "        if (x) y;", "    } while (x);", "    ", "}"])
    }

    func testEnterAfterUnclosedBraceIndentsAndClosingBraceOnBlankLineOutdents() throws {
        var editor = try self.editor("cpp")
        type("void f(void) {\nint x = 1;\n", into: &editor)
        XCTAssertEqual(editor.lines, ["void f(void) {", "    int x = 1;", "    "])
        editor.apply(.character("}"))
        XCTAssertEqual(editor.lines, ["void f(void) {", "    int x = 1;", "}"])
        XCTAssertEqual(editor.column, 1)
    }

    func testRightAndLeftWrapAcrossLines() throws {
        var editor = try self.editor("cpp")
        type("a\n  b", into: &editor)
        editor.apply(.left); editor.apply(.left); editor.apply(.left)
        XCTAssertEqual(editor.column, 0)
        editor.apply(.left)
        XCTAssertEqual((editor.row, editor.column).0, 0)
        XCTAssertEqual(editor.column, 1)
        editor.apply(.right)
        XCTAssertEqual(editor.row, 1)
        XCTAssertEqual(editor.column, 0)
        XCTAssertEqual(editor.remainder, "  b")
    }

    func testBackspaceInLeadingWhitespaceGoesToPreviousTabStop() throws {
        var editor = try self.editor("cpp")
        type("if (a) {\nif (b) {\n", into: &editor)
        XCTAssertEqual(editor.beforeCursor, "        ")
        editor.apply(.backspace)
        XCTAssertEqual(editor.beforeCursor, "    ")
        editor.apply(.backspace)
        XCTAssertEqual(editor.beforeCursor, "")
        editor.apply(.backspace)
        XCTAssertEqual(editor.row, 1, "backspace at column zero joins with the line above")
        XCTAssertEqual(editor.lines.count, 2)
    }

    func testAutoWhitespaceIsTrimmedWhenLeftBehind() throws {
        var editor = try self.editor("python")
        type("def f():\nx = 1\n\ny = 2", into: &editor)
        XCTAssertEqual(editor.lines, ["def f():", "    x = 1", "", "    y = 2"], "the blank line loses its automatic indentation, the next line keeps it")
        var cpp = try self.editor("cpp")
        type("int main(void) {}", into: &cpp)
        cpp.apply(.left)
        cpp.apply(.enter)
        cpp.apply(.enter)
        XCTAssertEqual(cpp.lines, ["int main(void) {", "", "    ", "}"])
    }

    func testPythonIndentsAfterColonAndNeverOutdentsOnItsOwn() throws {
        var editor = try self.editor("python")
        type("if a:\nb()\n", into: &editor)
        XCTAssertEqual(editor.beforeCursor, "    ")
        editor.apply(.backspace)
        type("elif c:\nd()\n", into: &editor)
        XCTAssertEqual(editor.lines, ["if a:", "    b()", "elif c:", "    d()", "    "])
        editor.apply(.character(")"))
        XCTAssertEqual(editor.lines.last, "    )", "a closing bracket with no opener above stays where it is")
    }

    func testElectricClosingBracketTakesTheOpeningLinesIndentation() throws {
        var editor = try self.editor("python")
        type("if a:\nx = foo(\na,\n", into: &editor)
        XCTAssertEqual(editor.beforeCursor, "        ", "the bracket rule indents after an open parenthesis")
        editor.apply(.character(")"))
        XCTAssertEqual(editor.lines, ["if a:", "    x = foo(", "        a,", "    )"], "the opening bracket's line is indented four, so the bracket lands there")
        var same = try self.editor("python")
        type("x = (1,\n", into: &same)
        same.apply(.tab)
        same.apply(.character(")"))
        XCTAssertEqual(same.lines, ["x = (1,", ")"], "matched on a different line: the line moves to that line's indentation")
    }

    func testScriptContentUsesTheEmbeddedRules() throws {
        var profile = try CompileFixture.profile("html")
        profile.embedded = ["script": try CompileFixture.profile("cpp").rules]
        var editor = VirtualEditor(profile: profile)
        type("<script>\nfunction f() {}", into: &editor)
        editor.apply(.left)
        editor.apply(.enter)
        XCTAssertEqual(editor.lines, ["<script>", "    function f() {", "        ", "    }"], "inside script the brace rules of the embedded language expand the pair")
        type("return 1;", into: &editor)
        editor.apply(.right); editor.apply(.right); editor.apply(.right); editor.apply(.right); editor.apply(.right); editor.apply(.right)
        editor.apply(.enter)
        editor.apply(.backspace)
        type("</script>", into: &editor)
        XCTAssertEqual(editor.lines.last, "</script>")
    }

    func testCppOutdentsAfterSingleStatementIf() throws {
        var editor = try self.editor("cpp")
        type("if (x)\n", into: &editor)
        XCTAssertEqual(editor.beforeCursor, "", "no rule indents after a braceless if; the user presses Tab")
        editor.apply(.tab)
        type("return;\n", into: &editor)
        XCTAssertEqual(editor.lines, ["if (x)", "    return;", ""], "the built-in onEnterRule moves the next line back out")
    }

    func testTabsProfileNormalizesWithTabs() throws {
        var editor = VirtualEditor(profile: try CompileFixture.profile("cpp", tabSize: 8, insertSpaces: false))
        type("int main(void) {\n", into: &editor)
        XCTAssertEqual(editor.lines[1], "\t")
        editor.apply(.tab)
        XCTAssertEqual(editor.lines[1], "\t\t")
        editor.apply(.backspace)
        XCTAssertEqual(editor.lines[1], "\t")
    }
}
