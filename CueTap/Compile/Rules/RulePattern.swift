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
