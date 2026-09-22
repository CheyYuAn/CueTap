import Foundation

/// One editor setting the demo depends on, compared with what the user's settings file says.
struct SettingsFinding: Codable {
    let severity: String
    let key: String
    let expected: String
    let actual: String
    let note: String
}

/// Reads VS Code's user settings and reports the ones a demo depends on. The compiler cannot see the
/// running editor, so this is the nearest thing to catching a setting that would break the typing.
enum EditorSettingsCheck {
    static var vsCodeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Code/User/settings.json")
    }

    /// User settings, plus the workspace settings of the folder that holds the targets: VS Code applies
    /// .vscode/settings.json of an open folder over the user file.
    static func vsCode(profile: EditorProfile, targets: [URL]) -> (file: String?, findings: [SettingsFinding]) {
        guard profile.name.hasPrefix("vscode-") else { return (nil, []) }
        return check(profile: profile, settingsURL: vsCodeSettingsURL, workspaceURL: targets.lazy.compactMap(workspaceSettings(near:)).first)
    }

    /// The nearest .vscode/settings.json above a target file, stopping at the home directory.
    static func workspaceSettings(near target: URL) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        var folder = target.standardizedFileURL.deletingLastPathComponent()
        while folder.path.count > 1 {
            let candidate = folder.appendingPathComponent(".vscode/settings.json")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            if folder.path == home { break }
            folder.deleteLastPathComponent()
        }
        return nil
    }

    private static func load(_ url: URL) -> [String: Any]?? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: Data(EditorRules.stripComments(String(decoding: data, as: UTF8.self)).utf8)),
              let root = object as? [String: Any] else { return .some(nil) }
        return root
    }

    static func check(profile: EditorProfile, settingsURL: URL, workspaceURL: URL? = nil) -> (file: String?, findings: [SettingsFinding]) {
        var findings: [SettingsFinding] = []
        var files: [String] = []
        var root: [String: Any] = [:]
        var override: [String: Any] = [:]
        var loadedAny = false
        for (url, label) in [(settingsURL, "user"), (workspaceURL, "workspace")] {
            guard let url else { continue }
            guard let loaded = load(url) else {
                if label == "user" { findings.append(SettingsFinding(severity: "info", key: "settings.json", expected: "readable", actual: "not found at \(url.path)", note: "No user settings were checked; confirm the editor settings by hand.")) }
                continue
            }
            guard let parsed = loaded else {
                files.append(url.path)
                findings.append(SettingsFinding(severity: "warning", key: url.lastPathComponent, expected: "valid JSON", actual: "unparseable at \(url.path)", note: "This settings file could not be parsed, so its values were not checked."))
                continue
            }
            loadedAny = true
            files.append(url.path)
            root.merge(parsed) { _, workspace in workspace }
            if let language = profile.languageId, let block = parsed["[\(language)]"] as? [String: Any] { override.merge(block) { _, workspace in workspace } }
        }
        guard loadedAny else { return (files.isEmpty ? nil : files.joined(separator: "; "), findings) }
        func value(_ key: String) -> Any? { override[key] ?? root[key] }
        func describe(_ value: Any?) -> String {
            guard let value else { return "(not set)" }
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) { return String(decoding: data, as: UTF8.self) }
            return String(describing: value)
        }
        func expect(_ key: String, _ expected: String, severity: String, note: String, satisfied: (Any?) -> Bool) {
            let actual = value(key)
            if !satisfied(actual) { findings.append(SettingsFinding(severity: severity, key: key, expected: expected, actual: describe(actual), note: note)) }
        }
        expect("editor.autoClosingBrackets", "\"never\"", severity: "warning", note: "The configuration types both halves of every bracket pair; the editor must not add the second half.") { ($0 as? String) == "never" }
        expect("editor.autoClosingQuotes", "\"never\"", severity: "warning", note: "The configuration types both quotes of every string; the editor must not add the second one.") { ($0 as? String) == "never" }
        expect("editor.autoIndent", "\"full\" or not set", severity: "warning", note: "The compiler predicts indentation from the language rules, which only apply with full auto indent.") { $0 == nil || ($0 as? String) == "full" }
        expect("editor.formatOnType", "false or not set", severity: "warning", note: "Formatting while typing rewrites lines the configuration has already typed.") { $0 == nil || ($0 as? Bool) == false }
        // VS Code indents with four spaces unless told otherwise, so an unset value means four.
        expect("editor.tabSize", "\(profile.tabSize)" + (profile.tabSize == 4 ? " or not set" : ""), severity: "warning", note: "The profile assumes this tab size; set it for this language or pass --tab-size to match the editor. In an open file the status bar's Spaces item changes it too.") { ($0 as? Int ?? 4) == profile.tabSize }
        expect("editor.insertSpaces", "\(profile.insertSpaces)" + (profile.insertSpaces ? " or not set" : ""), severity: "warning", note: "The profile assumes this indentation style; set it for this language or pass --tabs to match the editor.") { ($0 as? Bool ?? true) == profile.insertSpaces }
        expect("editor.acceptSuggestionOnEnter", "\"off\"", severity: "info", note: "With the suggestion list open, Enter would accept a suggestion instead of breaking the line.") { ($0 as? String) == "off" }
        expect("editor.acceptSuggestionOnCommitCharacter", "false", severity: "info", note: "Punctuation could accept a suggestion and replace the word just typed.") { ($0 as? Bool) == false }
        if profile.tags {
            for key in ["html.autoClosingTags", "javascript.autoClosingTags", "typescript.autoClosingTags"] {
                expect(key, "false", severity: "warning", note: "The configuration types every closing tag itself; the editor must not complete tags.") { ($0 as? Bool) == false }
            }
        }
        return (files.joined(separator: "; "), findings)
    }
}
