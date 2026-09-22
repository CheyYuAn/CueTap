import Foundation

/// Test doubles for the compiler: rule snapshots and target texts kept beside the tests, so the suite
/// does not depend on which VS Code, if any, is installed on the machine running it.
enum CompileFixture {
    static let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    static func url(_ name: String) -> URL { directory.appendingPathComponent(name) }
    static func profile(_ language: String, tabSize: Int = 4, insertSpaces: Bool = true) throws -> EditorProfile {
        let rulesURL = url("vscode-\(language)-language-configuration.json")
        return EditorProfile(name: "vscode-\(language)", rules: try EditorRules.load(from: rulesURL), rulesSource: rulesURL.path,
                             tabSize: tabSize, insertSpaces: insertSpaces, tags: ["html", "vue"].contains(language), languageId: language == "cpp" ? "c" : language)
    }
    static func text(_ name: String) throws -> String { try String(contentsOf: url(name), encoding: .utf8) }
}
