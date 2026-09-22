import Foundation

/// A pattern from a language configuration. VS Code writes JavaScript regular expressions; every
/// pattern shipped with its built-in languages is also valid ICU syntax, which NSRegularExpression uses.
struct RulePattern {
    let source: String
    private let regex: NSRegularExpression

    init(_ source: String, flags: String = "") throws {
        var options: NSRegularExpression.Options = []
        if flags.contains("i") { options.insert(.caseInsensitive) }
        if flags.contains("s") { options.insert(.dotMatchesLineSeparators) }
        if flags.contains("m") { options.insert(.anchorsMatchLines) }
        do { regex = try NSRegularExpression(pattern: Self.icuCompatible(source), options: options) }
        catch { throw ScriptError("Unsupported pattern \(source): \(error)") }
        self.source = source
    }

    /// JavaScript treats a brace that does not form a quantifier as a literal character; ICU rejects
    /// it. Escape those braces so the same pattern compiles, leaving real quantifiers and classes alone.
    static func icuCompatible(_ pattern: String) -> String {
        let characters = Array(pattern)
        var output = ""
        var index = 0
        var inClass = false
        var quantifierEnds: Set<Int> = []
        while index < characters.count {
            let character = characters[index]
            if character == "\\", index + 1 < characters.count {
                output.append(character); output.append(characters[index + 1]); index += 2; continue
            }
            if inClass {
                if character == "]" { inClass = false }
                output.append(character); index += 1; continue
            }
            if character == "[" { inClass = true; output.append(character); index += 1; continue }
            if character == "{" {
                var scan = index + 1
                var digits = 0
                while scan < characters.count, characters[scan].isNumber { scan += 1; digits += 1 }
                if scan < characters.count, characters[scan] == "," {
                    scan += 1
                    while scan < characters.count, characters[scan].isNumber { scan += 1 }
                }
                if digits > 0, scan < characters.count, characters[scan] == "}" {
                    quantifierEnds.insert(scan)
                    output.append(character)
                } else { output += "\\{" }
                index += 1; continue
            }
            if character == "}" {
                output += quantifierEnds.contains(index) ? "}" : "\\}"
                index += 1; continue
            }
            output.append(character); index += 1
        }
        return output
    }

    func matches(_ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }
}

enum IndentAction: String { case none, indent, indentOutdent, outdent }

struct OnEnterRule {
    let beforeText: RulePattern
    let afterText: RulePattern?
    let previousLineText: RulePattern?
    let action: IndentAction
    let appendText: String
    let removeText: Int
}

/// One bracket pair plus the regular expressions VS Code derives from it for Enter handling.
struct BracketPair {
    let open: String
    let close: String
    let openAtEnd: RulePattern
    let closeAtStart: RulePattern

    init(open: String, close: String) throws {
        self.open = open
        self.close = close
        var openSource = NSRegularExpression.escapedPattern(for: open)
        if let first = open.first, first.isLetter || first.isNumber || first == "_" { openSource = "\\b" + openSource }
        openAtEnd = try RulePattern(openSource + "\\s*$")
        var closeSource = NSRegularExpression.escapedPattern(for: close)
        if let last = close.last, last.isLetter || last.isNumber || last == "_" { closeSource += "\\b" }
        closeAtStart = try RulePattern("^\\s*" + closeSource)
    }
}

/// The parts of a VS Code language-configuration.json that decide what Enter, Tab, Backspace and
/// a typed closing bracket do. The same shape describes any editor whose behaviour can be written
/// down as these rules, so a hand-written file for another editor loads the same way.
struct EditorRules {
    let brackets: [BracketPair]
    let increaseIndent: RulePattern?
    let decreaseIndent: RulePattern?
    let indentNextLine: RulePattern?
    let unIndentedLine: RulePattern?
    let onEnterRules: [OnEnterRule]
    let lineComment: String?
    let blockComment: (start: String, end: String)?
    /// Single-character string delimiters, taken from auto-closing pairs whose two halves are the same.
    let quotes: [Character]

    var hasIndentationRules: Bool {
        increaseIndent != nil || decreaseIndent != nil || indentNextLine != nil || unIndentedLine != nil
    }

    func shouldIncrease(_ text: String) -> Bool { increaseIndent?.matches(text) ?? false }
    func shouldDecrease(_ text: String) -> Bool { decreaseIndent?.matches(text) ?? false }
    func shouldIndentNextLine(_ text: String) -> Bool { indentNextLine?.matches(text) ?? false }
    func shouldIgnore(_ text: String) -> Bool { unIndentedLine?.matches(text) ?? false }

    static func load(from url: URL) throws -> EditorRules {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw ControlError("rules_unreadable", "Cannot read editor rules at \(url.path): \(error)") }
        do { return try parse(data) }
        catch { throw ControlError("rules_unreadable", "Editor rules at \(url.path): \(error)") }
    }

    static func parse(_ data: Data) throws -> EditorRules {
        let stripped = stripComments(String(decoding: data, as: UTF8.self))
        let object: Any
        do { object = try JSONSerialization.jsonObject(with: Data(stripped.utf8)) }
        catch { throw ScriptError("not valid JSON: \(error)") }
        guard let root = object as? [String: Any] else { throw ScriptError("the root must be an object.") }

        var brackets: [BracketPair] = []
        for entry in root["brackets"] as? [[String]] ?? [] where entry.count == 2 {
            brackets.append(try BracketPair(open: entry[0], close: entry[1]))
        }
        let indentation = root["indentationRules"] as? [String: Any] ?? [:]
        var rules: [OnEnterRule] = []
        for entry in root["onEnterRules"] as? [[String: Any]] ?? [] {
            guard let before = try pattern(entry["beforeText"]) else { throw ScriptError("onEnterRules entries need beforeText.") }
            let action = entry["action"] as? [String: Any] ?? [:]
            let kind: IndentAction
            switch action["indent"] as? String ?? "none" {
            case "none": kind = .none
            case "indent": kind = .indent
            case "indentOutdent": kind = .indentOutdent
            case "outdent": kind = .outdent
            case let other: throw ScriptError("unknown indent action \(other).")
            }
            rules.append(OnEnterRule(beforeText: before, afterText: try pattern(entry["afterText"]),
                                     previousLineText: try pattern(entry["previousLineText"]), action: kind,
                                     appendText: action["appendText"] as? String ?? "",
                                     removeText: action["removeText"] as? Int ?? 0))
        }
        let comments = root["comments"] as? [String: Any] ?? [:]
        var block: (String, String)?
        if let pair = comments["blockComment"] as? [String], pair.count == 2 { block = (pair[0], pair[1]) }
        var quotes: [Character] = []
        for pair in root["autoClosingPairs"] as? [Any] ?? [] {
            var open: String?, close: String?
            if let object = pair as? [String: Any] { open = object["open"] as? String; close = object["close"] as? String }
            else if let array = pair as? [String], array.count == 2 { open = array[0]; close = array[1] }
            if let open, open == close, open.count == 1, let character = open.first, !quotes.contains(character) { quotes.append(character) }
        }
        return EditorRules(brackets: brackets,
                           increaseIndent: try pattern(indentation["increaseIndentPattern"]),
                           decreaseIndent: try pattern(indentation["decreaseIndentPattern"]),
                           indentNextLine: try pattern(indentation["indentNextLinePattern"]),
                           unIndentedLine: try pattern(indentation["unIndentedLinePattern"]),
                           onEnterRules: rules, lineComment: comments["lineComment"] as? String,
                           blockComment: block, quotes: quotes)
    }

    private static func pattern(_ value: Any?) throws -> RulePattern? {
        if value == nil { return nil }
        if let source = value as? String { return try RulePattern(source) }
        if let object = value as? [String: Any], let source = object["pattern"] as? String {
            return try RulePattern(source, flags: object["flags"] as? String ?? "")
        }
        throw ScriptError("a pattern must be a string or an object with a pattern field.")
    }

    /// Some language configurations are JSON with comments and trailing commas.
    static func stripComments(_ text: String) -> String {
        var output = ""
        var characters = Array(text)
        var index = 0
        var inString = false
        while index < characters.count {
            let character = characters[index]
            if inString {
                output.append(character)
                if character == "\\", index + 1 < characters.count { output.append(characters[index + 1]); index += 1 }
                else if character == "\"" { inString = false }
                index += 1
                continue
            }
            if character == "\"" { inString = true; output.append(character); index += 1; continue }
            if character == "/", index + 1 < characters.count, characters[index + 1] == "/" {
                while index < characters.count, characters[index] != "\n" { index += 1 }
                continue
            }
            if character == "/", index + 1 < characters.count, characters[index + 1] == "*" {
                index += 2
                while index + 1 < characters.count, !(characters[index] == "*" && characters[index + 1] == "/") { index += 1 }
                index += 2
                continue
            }
            if character == "," {
                var lookahead = index + 1
                while lookahead < characters.count, characters[lookahead].isWhitespace { lookahead += 1 }
                if lookahead < characters.count, characters[lookahead] == "}" || characters[lookahead] == "]" { index += 1; continue }
            }
            output.append(character)
            index += 1
        }
        characters.removeAll()
        return output
    }
}

/// Rules from a second language configuration take precedence for Enter; VS Code applies the jsx-tags
/// rules inside JSX elements and the JavaScript rules elsewhere, which one document model approximates
/// by consulting the tag rules first.
extension EditorRules {
    func merging(tagRules: EditorRules) -> EditorRules {
        EditorRules(brackets: brackets, increaseIndent: increaseIndent, decreaseIndent: decreaseIndent, indentNextLine: indentNextLine,
                    unIndentedLine: unIndentedLine, onEnterRules: tagRules.onEnterRules + onEnterRules, lineComment: lineComment,
                    blockComment: blockComment, quotes: quotes)
    }
}

/// An editor plus language, with the indentation settings the compiler assumes.
struct EditorProfile {
    let name: String
    let rules: EditorRules
    let rulesSource: String
    var tabSize = 4
    var insertSpaces = true
    var tags = false
    var languageId: String?
    /// Rules for the content of script and style elements, keyed by element name.
    var embedded: [String: EditorRules] = [:]

    /// VS Code language ids whose documents are built from paired tags.
    static let tagLanguages: Set<String> = ["html", "vue", "xml", "xsl", "svelte", "astro", "javascriptreact", "typescriptreact", "jsx-tags", "handlebars", "razor", "php", "erb", "ejs", "twig", "blade"]
    static let exampleNames = ["vscode-c", "vscode-python", "vscode-html", "vscode-vue", "vscode-typescriptreact"]

    /// Resolve `vscode-<language id>` from the installed VS Code and its extensions, falling back to a
    /// bundled snapshot for a few languages, or load an explicit rules file which needs no name.
    static func resolve(name: String?, rulesPath: String?, tabSize: Int, insertSpaces: Bool, tags: Bool?) throws -> EditorProfile {
        if let rulesPath {
            let url = URL(fileURLWithPath: (rulesPath as NSString).expandingTildeInPath).standardizedFileURL
            return EditorProfile(name: name ?? "custom", rules: try EditorRules.load(from: url), rulesSource: url.path,
                                 tabSize: tabSize, insertSpaces: insertSpaces, tags: tags ?? false, languageId: nil)
        }
        guard let name, name.hasPrefix("vscode-"), name.count > "vscode-".count else {
            throw ControlError("profile_not_found", "Unknown profile \(name ?? "(none)"). Use vscode-<language id> for any language VS Code or one of its extensions defines, for example \(exampleNames.joined(separator: ", ")), or --rules FILE for another editor.")
        }
        let languageId = String(name.dropFirst("vscode-".count))
        let useTags = tags ?? tagLanguages.contains(languageId)
        if let url = VSCodeLanguages.configurationURL(for: languageId) {
            var rules = try EditorRules.load(from: url)
            var source = url.path
            if ["javascriptreact", "typescriptreact"].contains(languageId), let tagURL = VSCodeLanguages.configurationURL(for: "jsx-tags") {
                rules = rules.merging(tagRules: try EditorRules.load(from: tagURL))
                source += " with " + tagURL.path
            }
            var profile = EditorProfile(name: name, rules: rules, rulesSource: source, tabSize: tabSize, insertSpaces: insertSpaces, tags: useTags, languageId: languageId)
            if useTags { profile.embedded = embeddedRules() }
            return profile
        }
        if let snapshot = BuiltInRules.snapshots[languageId] {
            let rules: EditorRules
            do { rules = try EditorRules.parse(Data(snapshot.json.utf8)) }
            catch { throw ControlError("rules_unreadable", "Built-in rules for \(name): \(error)") }
            var profile = EditorProfile(name: name, rules: rules, rulesSource: "built-in snapshot of \(snapshot.origin)", tabSize: tabSize, insertSpaces: insertSpaces, tags: useTags, languageId: languageId)
            if useTags { profile.embedded = embeddedRules() }
            return profile
        }
        throw ControlError("profile_not_found", "No language \(languageId) is defined by the installed VS Code or the extensions in ~/.vscode/extensions, and CueTap has no snapshot for it. Install the extension that provides it, or pass --rules FILE.")
    }
}

extension EditorProfile {
    /// JavaScript rules for script elements and CSS rules for style elements, when VS Code has them.
    static func embeddedRules() -> [String: EditorRules] {
        var result: [String: EditorRules] = [:]
        for (element, language) in [("script", "javascript"), ("style", "css")] {
            if let url = VSCodeLanguages.configurationURL(for: language), let rules = try? EditorRules.load(from: url) { result[element] = rules }
        }
        return result
    }
}

/// Finds a language's configuration file the way VS Code does: every extension's package.json lists
/// the languages it contributes and where their language-configuration.json lives. Built-in extensions
/// are searched before user-installed ones.
enum VSCodeLanguages {
    static var extensionRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [URL(fileURLWithPath: "/Applications/Visual Studio Code.app/Contents/Resources/app/extensions"),
                home.appendingPathComponent("Applications/Visual Studio Code.app/Contents/Resources/app/extensions"),
                home.appendingPathComponent(".vscode/extensions")]
    }

    static func configurationURL(for languageId: String, roots: [URL]? = nil) -> URL? {
        for root in roots ?? extensionRoots {
            guard let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for folder in folders.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
                let manifest = folder.appendingPathComponent("package.json")
                guard let data = try? Data(contentsOf: manifest),
                      let object = try? JSONSerialization.jsonObject(with: Data(EditorRules.stripComments(String(decoding: data, as: UTF8.self)).utf8)),
                      let contributes = (object as? [String: Any])?["contributes"] as? [String: Any],
                      let languages = contributes["languages"] as? [[String: Any]] else { continue }
                for language in languages where language["id"] as? String == languageId {
                    guard let path = language["configuration"] as? String else { continue }
                    let url = folder.appendingPathComponent(path).standardizedFileURL
                    if FileManager.default.fileExists(atPath: url.path) { return url }
                }
            }
        }
        return nil
    }
}
