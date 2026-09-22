import Foundation

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
