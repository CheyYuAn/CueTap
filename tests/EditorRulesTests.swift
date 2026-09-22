import Foundation
import XCTest

final class EditorRulesTests: XCTestCase {
    func testCppRulesParseIntoIndentationAndEnterRules() throws {
        let rules = try CompileFixture.profile("cpp").rules
        XCTAssertEqual(rules.brackets.map(\.open), ["{", "[", "("])
        XCTAssertTrue(rules.hasIndentationRules)
        XCTAssertTrue(rules.shouldIncrease("    do { printf(\"x\"); n++;"))
        XCTAssertFalse(rules.shouldIncrease("    x = f(a);"))
        XCTAssertTrue(rules.shouldDecrease("    } while (x);"))
        XCTAssertFalse(rules.shouldDecrease("    if (x) {"))
        XCTAssertEqual(rules.onEnterRules.count, 2)
        XCTAssertEqual(rules.onEnterRules[0].action, .outdent)
        XCTAssertEqual(rules.onEnterRules[1].appendText, "// ")
        XCTAssertEqual(rules.lineComment, "//")
        XCTAssertEqual(rules.blockComment?.start, "/*")
        XCTAssertEqual(rules.quotes, ["'", "\""])
    }

    func testPythonRulesHaveOnlyTheColonEnterRule() throws {
        let rules = try CompileFixture.profile("python").rules
        XCTAssertFalse(rules.hasIndentationRules)
        XCTAssertEqual(rules.onEnterRules.count, 1)
        XCTAssertEqual(rules.onEnterRules[0].action, .indent)
        XCTAssertTrue(rules.onEnterRules[0].beforeText.matches("    elif guess > secret:"))
        XCTAssertFalse(rules.onEnterRules[0].beforeText.matches("    print(\"x\")"))
        XCTAssertEqual(rules.lineComment, "#")
        XCTAssertEqual(rules.blockComment?.start, "\"\"\"")
    }

    func testBracketRegularExpressionsMatchLikeVSCode() throws {
        let pair = try BracketPair(open: "{", close: "}")
        XCTAssertTrue(pair.openAtEnd.matches("int main(void) {"))
        XCTAssertTrue(pair.openAtEnd.matches("{  "))
        XCTAssertFalse(pair.openAtEnd.matches("do { x;"))
        XCTAssertTrue(pair.closeAtStart.matches("}"))
        XCTAssertTrue(pair.closeAtStart.matches("   } while (x);"))
        XCTAssertFalse(pair.closeAtStart.matches("x }"))
        let word = try BracketPair(open: "begin", close: "end")
        XCTAssertTrue(word.openAtEnd.matches("if x then begin"))
        XCTAssertFalse(word.openAtEnd.matches("xbegin"))
        XCTAssertFalse(word.closeAtStart.matches("endless"))
    }

    func testLiteralBracesFromJavaScriptPatternsCompile() throws {
        XCTAssertEqual(RulePattern.icuCompatible("a{2,3}b{4}c{,5}"), "a{2,3}b{4}c\\{,5\\}")
        XCTAssertEqual(RulePattern.icuCompatible("\\{[^}]*$|\\begin{(?!x)([^}]*)}"), "\\{[^}]*$|\\begin\\{(?!x)([^}]*)\\}")
        let go = try RulePattern("^.*(\\bcase\\b.*:|(\\b(func|if)\\b.*)?{[^}\"'`]*|\\([^)\"'`]*)$")
        XCTAssertTrue(go.matches("func main() {"))
        XCTAssertTrue(go.matches("    case 1:"))
        XCTAssertFalse(go.matches("    x := 1"))
        let json = try RulePattern("({+(?=((\\\\.|[^\"\\\\])*\"(\\\\.|[^\"\\\\])*\")*[^\"}]*)$)")
        XCTAssertTrue(json.matches("  \"a\": {"))
        XCTAssertFalse(json.matches("  \"a\": {}"))
        let latex = try RulePattern("\\\\begin{(?!document)([^}]*)}(?!.*\\\\end{\\1})")
        XCTAssertTrue(latex.matches("\\begin{itemize}"))
        XCTAssertFalse(latex.matches("\\begin{itemize} \\end{itemize}"))
    }

    func testCommentsAndTrailingCommasAreStrippedBeforeParsing() throws {
        let source = """
        {
          // comment
          "brackets": [["(", ")"],], /* block */
          "comments": { "lineComment": "//", },
          "indentationRules": { "increaseIndentPattern": { "pattern": "\\\\{$", "flags": "i" } }
        }
        """
        let rules = try EditorRules.parse(Data(source.utf8))
        XCTAssertEqual(rules.brackets.count, 1)
        XCTAssertEqual(rules.lineComment, "//")
        XCTAssertTrue(rules.shouldIncrease("a {"))
    }

    func testBuiltInSnapshotsMatchTheCheckedInCopies() throws {
        for (language, fixture) in [("cpp", "cpp"), ("python", "python"), ("html", "html"), ("vue", "vue")] {
            let file = try String(contentsOf: CompileFixture.url("vscode-\(fixture)-language-configuration.json"), encoding: .utf8)
            let snapshot = try XCTUnwrap(BuiltInRules.snapshots[language], language)
            XCTAssertEqual(file.trimmingCharacters(in: .whitespacesAndNewlines), snapshot.json.trimmingCharacters(in: .whitespacesAndNewlines), language)
        }
        for (language, snapshot) in BuiltInRules.snapshots { XCTAssertNoThrow(try EditorRules.parse(Data(snapshot.json.utf8)), language) }
    }

    func testHTMLAndVueRulesParseWithTagPatterns() throws {
        let html = try CompileFixture.profile("html").rules
        XCTAssertTrue(html.hasIndentationRules)
        XCTAssertEqual(html.onEnterRules.count, 2)
        XCTAssertTrue(html.onEnterRules[0].beforeText.matches("    <div class=\"counter\">"))
        XCTAssertTrue(html.onEnterRules[0].afterText!.matches("</div>"))
        XCTAssertFalse(html.onEnterRules[0].beforeText.matches("<br>"), "void elements do not indent")
        XCTAssertFalse(html.onEnterRules[0].beforeText.matches("<p>Count</p>"))
        XCTAssertTrue(html.shouldIncrease("<ul>"))
        XCTAssertFalse(html.shouldIncrease("<li>a</li>"))
        XCTAssertTrue(html.shouldDecrease("    </ul>"))
        XCTAssertEqual(html.blockComment?.start, "<!--")
        let vue = try CompileFixture.profile("vue").rules
        XCTAssertEqual(vue.onEnterRules.count, 2, "the Vue file is JSON with comments and still parses")
        XCTAssertFalse(vue.onEnterRules[0].beforeText.matches("<script>"), "Vue excludes script and style blocks")
    }

    func testMergedRulesConsultTheTagRulesFirst() throws {
        let merged = try CompileFixture.profile("cpp").rules.merging(tagRules: try CompileFixture.profile("html").rules)
        XCTAssertEqual(merged.onEnterRules.count, 4)
        XCTAssertEqual(merged.onEnterRules[0].action, .indentOutdent)
        XCTAssertEqual(merged.onEnterRules[2].action, .outdent)
        XCTAssertTrue(merged.hasIndentationRules)
        XCTAssertEqual(merged.brackets.map(\.open), ["{", "[", "("])
    }

    func testLanguageDiscoveryReadsExtensionManifests() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap ext \(UUID().uuidString)")
        let folder = root.appendingPathComponent("vendor.lang-1.0.0")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("languages"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try """
        { // manifest with a comment
          "contributes": { "languages": [ { "id": "demo", "configuration": "./languages/demo.json" }, ] }
        }
        """.write(to: folder.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try Data(BuiltInRules.cpp.utf8).write(to: folder.appendingPathComponent("languages/demo.json"))
        XCTAssertEqual(VSCodeLanguages.configurationURL(for: "demo", roots: [root])?.lastPathComponent, "demo.json")
        XCTAssertNil(VSCodeLanguages.configurationURL(for: "other", roots: [root]))
        // A second root with the same language loses to the first, the way built-in extensions win over user ones.
        let second = root.appendingPathComponent("user/other.lang-2.0.0")
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try #"{"contributes":{"languages":[{"id":"demo","configuration":"./user-demo.json"}]}}"#.write(to: second.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try Data(BuiltInRules.python.utf8).write(to: second.appendingPathComponent("user-demo.json"))
        XCTAssertEqual(VSCodeLanguages.configurationURL(for: "demo", roots: [root, root.appendingPathComponent("user")])?.lastPathComponent, "demo.json")
        XCTAssertEqual(VSCodeLanguages.configurationURL(for: "demo", roots: [root.appendingPathComponent("user"), root])?.lastPathComponent, "user-demo.json")
    }

    func testSettingsCheckReportsWhatTheDemoDependsOn() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap settings \(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        try """
        {
            // user settings
            "editor.autoClosingBrackets": "never",
            "editor.formatOnType": true,
            "[c]": { "editor.tabSize": 2 },
        }
        """.write(to: file, atomically: true, encoding: .utf8)
        let profile = try CompileFixture.profile("cpp")
        let result = EditorSettingsCheck.check(profile: profile, settingsURL: file)
        XCTAssertEqual(result.file, file.path)
        let byKey = Dictionary(uniqueKeysWithValues: result.findings.map { ($0.key, $0) })
        XCTAssertNil(byKey["editor.autoClosingBrackets"])
        XCTAssertEqual(byKey["editor.autoClosingQuotes"]?.severity, "warning")
        XCTAssertEqual(byKey["editor.autoClosingQuotes"]?.actual, "(not set)")
        XCTAssertEqual(byKey["editor.formatOnType"]?.actual, "true")
        XCTAssertEqual(byKey["editor.tabSize"]?.actual, "2", "the [c] language block overrides the top level")
        XCTAssertEqual(byKey["editor.acceptSuggestionOnEnter"]?.severity, "info")
        XCTAssertNil(byKey["html.autoClosingTags"], "tag settings are only checked for tag languages")
        let narrow = EditorSettingsCheck.check(profile: try CompileFixture.profile("python", tabSize: 2), settingsURL: file)
        XCTAssertEqual(narrow.findings.first { $0.key == "editor.tabSize" }?.actual, "(not set)", "an unset tab size means four, which is not two")
        let html = EditorSettingsCheck.check(profile: try CompileFixture.profile("html"), settingsURL: file)
        XCTAssertEqual(html.findings.first { $0.key == "html.autoClosingTags" }?.severity, "warning")
        let missing = EditorSettingsCheck.check(profile: profile, settingsURL: file.appendingPathExtension("missing"))
        XCTAssertNil(missing.file)
        XCTAssertEqual(missing.findings.count, 1)
        XCTAssertEqual(missing.findings[0].severity, "info")
    }

    func testWorkspaceSettingsOverrideUserSettings() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap workspace \(UUID().uuidString)")
        let user = root.appendingPathComponent("user.json")
        let project = root.appendingPathComponent("project/src")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("project/.vscode"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try #"{"editor.autoClosingBrackets": "never", "editor.autoClosingQuotes": "never", "editor.tabSize": 4}"#.write(to: user, atomically: true, encoding: .utf8)
        let workspace = root.appendingPathComponent("project/.vscode/settings.json")
        try #"{"editor.tabSize": 2, "[c]": {"editor.autoClosingQuotes": "always"}}"#.write(to: workspace, atomically: true, encoding: .utf8)
        let target = project.appendingPathComponent("main.c")
        XCTAssertEqual(EditorSettingsCheck.workspaceSettings(near: target), workspace)
        XCTAssertNil(EditorSettingsCheck.workspaceSettings(near: root.appendingPathComponent("elsewhere.c")))
        let result = EditorSettingsCheck.check(profile: try CompileFixture.profile("cpp"), settingsURL: user, workspaceURL: workspace)
        XCTAssertEqual(result.file, "\(user.path); \(workspace.path)")
        let byKey = Dictionary(uniqueKeysWithValues: result.findings.map { ($0.key, $0) })
        XCTAssertEqual(byKey["editor.tabSize"]?.actual, "2", "the workspace value replaces the user value")
        XCTAssertEqual(byKey["editor.autoClosingQuotes"]?.actual, "\"always\"", "the workspace language block replaces the user value")
        XCTAssertNil(byKey["editor.autoClosingBrackets"])
    }

    func testUnknownProfileNamesBuiltInsAndCustomRulesNeedNoName() throws {
        XCTAssertThrowsError(try EditorProfile.resolve(name: "vim-c", rulesPath: nil, tabSize: 4, insertSpaces: true, tags: nil)) { error in
            XCTAssertEqual((error as? ControlError)?.code, "profile_not_found")
            XCTAssertTrue(String(describing: error).contains("vscode-python"))
        }
        XCTAssertThrowsError(try EditorProfile.resolve(name: "vscode-no-such-language-xyz", rulesPath: nil, tabSize: 4, insertSpaces: true, tags: nil)) { error in
            XCTAssertEqual((error as? ControlError)?.code, "profile_not_found")
        }
        let custom = try EditorProfile.resolve(name: nil, rulesPath: CompileFixture.url("vscode-cpp-language-configuration.json").path, tabSize: 2, insertSpaces: false, tags: nil)
        XCTAssertEqual(custom.name, "custom")
        XCTAssertEqual(custom.tabSize, 2)
        XCTAssertFalse(custom.insertSpaces)
        XCTAssertFalse(custom.tags)
        XCTAssertThrowsError(try EditorProfile.resolve(name: nil, rulesPath: "/nonexistent/rules.json", tabSize: 4, insertSpaces: true, tags: nil)) { error in
            XCTAssertEqual((error as? ControlError)?.code, "rules_unreadable")
        }
        let vue = try EditorProfile.resolve(name: "vscode-vue", rulesPath: nil, tabSize: 4, insertSpaces: true, tags: nil)
        XCTAssertTrue(vue.tags, "tag languages pair tags by default")
        XCTAssertEqual(vue.languageId, "vue")
        XCTAssertEqual(vue.rules.onEnterRules.count, 2)
        let python = try EditorProfile.resolve(name: "vscode-python", rulesPath: nil, tabSize: 4, insertSpaces: true, tags: nil)
        XCTAssertFalse(python.tags)
    }
}
