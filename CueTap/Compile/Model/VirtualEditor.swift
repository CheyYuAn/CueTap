import Foundation

/// A document plus cursor that reacts to keystrokes the way VS Code does with editor.autoIndent set to
/// full, auto-closing pairs off and trimAutoWhitespace on. The Enter, Tab, Backspace and closing-bracket
/// behaviour follows the editor's own source order: bracket rules and onEnterRules first, then the
/// indentationRules of the language, then keeping the current indentation. Everything here is text;
/// nothing talks to a real editor.
struct VirtualEditor {
    let profile: EditorProfile
    private(set) var lines: [String] = [""]
    private(set) var row = 0
    private(set) var column = 0
    /// Lines whose whole content is whitespace the editor inserted on its own. VS Code removes that
    /// whitespace again when the next edit lands somewhere else, or when Enter is pressed at its end.
    private var autoWhitespaceRows: Set<Int> = []

    init(profile: EditorProfile) { self.profile = profile }

    /// The rules in force at the cursor: those of an embedded language when the cursor sits inside a
    /// script or style element, otherwise the profile's own. VS Code picks the language from the
    /// token under the cursor and applies its rules to the lines above as well.
    var rules: EditorRules { embeddedRules() ?? profile.rules }

    private func embeddedRules() -> EditorRules? {
        guard !profile.embedded.isEmpty else { return nil }
        let above = lines[..<row].joined(separator: "\n").lowercased()
        var best: (name: String, position: String.Index)?
        for name in profile.embedded.keys {
            guard let open = above.range(of: "<" + name, options: .backwards) else { continue }
            if let close = above.range(of: "</" + name, options: .backwards), close.lowerBound > open.lowerBound { continue }
            if best == nil || open.lowerBound > best!.position { best = (name, open.lowerBound) }
        }
        return best.flatMap { profile.embedded[$0.name] }
    }
    var text: String { lines.joined(separator: "\n") }
    var beforeCursor: String { String(lines[row].prefix(column)) }
    var afterCursor: String { String(lines[row].dropFirst(column)) }
    /// Everything from the cursor to the end of the document.
    var remainder: String { ([afterCursor] + lines[(row + 1)...]).joined(separator: "\n") }

    mutating func apply(_ action: DemoAction) {
        switch action {
        case .character(let character): type(character)
        case .enter: enter()
        case .tab: tab()
        case .backspace: backspace()
        case .left:
            if column > 0 { column -= 1 }
            else if row > 0 { row -= 1; column = lines[row].count }
        case .right:
            if column < lines[row].count { column += 1 }
            else if row + 1 < lines.count { row += 1; column = 0 }
        }
    }

    // MARK: Typing

    private mutating func type(_ character: Character) {
        let trims = trimCandidates(excluding: [row])
        if rules.hasIndentationRules, let reindented = reindentForClosing(character) {
            lines[row] = reindented.line
            column = reindented.column
        } else if let reindented = electricReindent(character) {
            lines[row] = reindented.line
            column = reindented.column
        } else {
            lines[row] = beforeCursor + String(character) + afterCursor
            column += 1
        }
        autoWhitespaceRows = []
        applyTrims(trims, editRow: row, delta: 0)
    }

    /// Typing a character that makes the line match decreaseIndentPattern moves the line to the
    /// indentation its context asks for, which is how a closing brace on a blank line lines up.
    private func reindentForClosing(_ character: Character) -> (line: String, column: Int)? {
        let before = beforeCursor, after = afterCursor
        guard !rules.shouldDecrease(before + after), rules.shouldDecrease(before + String(character) + after),
              let inherited = inheritedIndent(forLine: row, lineContent: { lines[$0] }, honorIntentional: false) else { return nil }
        var indentation = inherited.indentation
        if inherited.action != .indent { indentation = unshift(indentation) }
        let normalized = normalize(indentation)
        guard normalized != normalize(leadingWhitespace(before)) else { return nil }
        let line = lines[row]
        let firstNonWhitespace = line.firstIndex { !$0.isWhitespace }
        let cursor = line.index(line.startIndex, offsetBy: column)
        let kept = firstNonWhitespace.map { $0 < cursor ? String(line[$0..<cursor]) : "" } ?? ""
        return (normalized + kept + String(character) + after, normalized.count + kept.count + 1)
    }

    /// A closing bracket typed as the first thing on a line takes the indentation of the line that
    /// holds its opening bracket, when that line is a different one. This is VS Code's electric
    /// character handling, which runs when the indentation rules did not already move the line.
    private func electricReindent(_ character: Character) -> (line: String, column: Int)? {
        guard let bracket = rules.brackets.first(where: { $0.close == String(character) }), bracket.open.count == 1,
              beforeCursor.allSatisfy(\.isWhitespace) else { return nil }
        let open = bracket.open.first!
        var depth = 0
        var matchRow: Int?
        search: for probe in stride(from: row, through: 0, by: -1) {
            let text = probe == row ? beforeCursor : lines[probe]
            for candidate in text.reversed() {
                if candidate == character { depth += 1 }
                else if candidate == open {
                    if depth == 0 { matchRow = probe; break search }
                    depth -= 1
                }
            }
        }
        guard let matchRow, matchRow != row else { return nil }
        let indentation = normalize(leadingWhitespace(lines[matchRow]))
        guard indentation != beforeCursor else { return nil }
        return (indentation + String(character) + afterCursor, indentation.count + 1)
    }

    // MARK: Enter

    private struct EnterAction {
        let action: IndentAction
        let appendText: String
        let indentation: String
    }

    private func enterAction(before: String, after: String, previousLine: String) -> EnterAction? {
        var result: (IndentAction, String, Int)?
        for bracket in rules.brackets where bracket.openAtEnd.matches(before) && bracket.closeAtStart.matches(after) {
            result = (.indentOutdent, "", 0)
            break
        }
        if result == nil {
            for rule in rules.onEnterRules where rule.beforeText.matches(before)
                && (rule.afterText?.matches(after) ?? true) && (rule.previousLineText?.matches(previousLine) ?? true) {
                result = (rule.action, rule.appendText, rule.removeText)
                break
            }
        }
        if result == nil {
            for bracket in rules.brackets where bracket.openAtEnd.matches(before) { result = (.indent, "", 0); break }
        }
        guard let (action, text, removeText) = result else { return nil }
        var appendText = text
        if appendText.isEmpty { appendText = action == .indent || action == .indentOutdent ? "\t" : "" }
        else if action == .indent { appendText = "\t" + appendText }
        var indentation = leadingWhitespace(before)
        if removeText > 0 { indentation = String(indentation.dropLast(removeText)) }
        return EnterAction(action: action, appendText: appendText, indentation: indentation)
    }

    private mutating func enter() {
        let before = beforeCursor, after = afterCursor
        let line = lines[row]
        let trims = trimCandidates(excluding: column == line.count ? [] : [row])
        let previousLine = row > 0 ? lines[row - 1] : ""
        let editRow = row
        var inserted = 1
        if profile.plain {
            // A text field just breaks the line; whatever follows the cursor moves down unindented.
            replaceCurrentLine(with: [before, after], cursorRow: 1, cursorColumn: 0)
            autoWhitespaceRows = []
            return
        }
        if let action = enterAction(before: before, after: after, previousLine: previousLine) {
            switch action.action {
            case .none, .indent:
                let indentation = normalize(action.indentation + action.appendText)
                replaceCurrentLine(with: [before, indentation + after], cursorRow: 1, cursorColumn: indentation.count)
            case .indentOutdent:
                let normal = normalize(action.indentation)
                let increased = normalize(action.indentation + action.appendText)
                replaceCurrentLine(with: [before, increased, normal + after], cursorRow: 1, cursorColumn: increased.count)
                inserted = 2
            case .outdent:
                let indentation = normalize(unshift(action.indentation) + action.appendText)
                replaceCurrentLine(with: [before, indentation + after], cursorRow: 1, cursorColumn: indentation.count)
            }
        } else if rules.hasIndentationRules {
            var indentation = leadingWhitespace(before)
            if let inherited = inheritedIndent(forLine: row + 1, lineContent: { $0 == row ? before : lines[$0] }, honorIntentional: true) {
                indentation = inherited.indentation
                if inherited.action == .indent { indentation = shift(indentation) }
            }
            if rules.shouldDecrease(after) { indentation = unshift(indentation) }
            let normalized = normalize(indentation)
            // The editor swallows the whitespace between the cursor and the first character after it.
            let firstNonWhitespace = line.firstIndex { !$0.isWhitespace }.map { line.distance(from: line.startIndex, to: $0) }
            let cut = firstNonWhitespace.map { max(column, $0) } ?? line.count
            let rest = String(line.dropFirst(cut))
            var cursorColumn = normalized.count
            if let firstNonWhitespace, column <= firstNonWhitespace { cursorColumn = min(visibleWidth(before), normalized.count) }
            replaceCurrentLine(with: [before, normalized + rest], cursorRow: 1, cursorColumn: cursorColumn)
        } else {
            let indentation = normalize(leadingWhitespace(before))
            replaceCurrentLine(with: [before, indentation + after], cursorRow: 1, cursorColumn: indentation.count)
        }
        applyTrims(trims, editRow: editRow, delta: inserted)
        autoWhitespaceRows = []
        for offset in 1...inserted where isAutoWhitespace(lines[editRow + offset]) { autoWhitespaceRows.insert(editRow + offset) }
    }

    private mutating func replaceCurrentLine(with replacement: [String], cursorRow: Int, cursorColumn: Int) {
        lines.replaceSubrange(row...row, with: replacement)
        row += cursorRow
        column = cursorColumn
    }

    /// VS Code's getInheritIndentForLine: which earlier line a new line takes its indentation from.
    private func inheritedIndent(forLine target: Int, lineContent content: (Int) -> String, honorIntentional: Bool)
        -> (indentation: String, action: IndentAction?)? {
        guard target > 0 else { return ("", nil) }
        var probe = target - 1
        while probe >= 0 {
            if !content(probe).isEmpty { break }
            if probe == 0 { return ("", nil) }
            probe -= 1
        }
        var preceding = -1
        probe = target - 1
        while probe >= 0 {
            let text = content(probe)
            if rules.shouldIgnore(text) || text.allSatisfy(\.isWhitespace) { probe -= 1; continue }
            preceding = probe
            break
        }
        if preceding < 0 { preceding = 0 }
        let text = content(preceding)
        if rules.shouldIncrease(text) || rules.shouldIndentNextLine(text) { return (leadingWhitespace(text), .indent) }
        if rules.shouldDecrease(text) { return (leadingWhitespace(text), nil) }
        if preceding == 0 { return (leadingWhitespace(text), nil) }
        let previousText = content(preceding - 1)
        if !(rules.shouldIncrease(previousText) || rules.shouldDecrease(previousText)), rules.shouldIndentNextLine(previousText) {
            var stop = -1
            var index = preceding - 2
            while index >= 0 {
                if rules.shouldIndentNextLine(content(index)) { index -= 1; continue }
                stop = index
                break
            }
            return (leadingWhitespace(content(stop + 1)), nil)
        }
        if honorIntentional { return (leadingWhitespace(text), nil) }
        var index = preceding
        while index >= 0 {
            let candidate = content(index)
            if rules.shouldIncrease(candidate) { return (leadingWhitespace(candidate), .indent) }
            if rules.shouldIndentNextLine(candidate) {
                var stop = -1
                var inner = index - 1
                while inner >= 0 {
                    if rules.shouldIndentNextLine(content(inner)) { inner -= 1; continue }
                    stop = inner
                    break
                }
                return (leadingWhitespace(content(stop + 1)), nil)
            }
            if rules.shouldDecrease(candidate) { return (leadingWhitespace(candidate), nil) }
            index -= 1
        }
        return (leadingWhitespace(content(0)), nil)
    }

    // MARK: Tab and Backspace

    private mutating func tab() {
        let trims = trimCandidates(excluding: [row])
        let line = lines[row]
        var handled = false
        if line.allSatisfy(\.isWhitespace), let good = goodIndent(forLine: row) {
            let possible = normalize(good)
            if !line.hasPrefix(possible) {
                lines[row] = possible
                column = possible.count
                handled = true
            }
        }
        if !handled {
            let insertion: String
            if profile.insertSpaces {
                let width = profile.tabSize - visibleWidth(beforeCursor) % profile.tabSize
                insertion = String(repeating: " ", count: width)
            } else { insertion = "\t" }
            lines[row] = beforeCursor + insertion + afterCursor
            column += insertion.count
        }
        autoWhitespaceRows = []
        applyTrims(trims, editRow: row, delta: 0)
        if isAutoWhitespace(lines[row]) { autoWhitespaceRows.insert(row) }
    }

    /// The indentation Tab jumps to on a blank line.
    private func goodIndent(forLine target: Int) -> String? {
        var action: IndentAction?
        var indentation = ""
        if rules.hasIndentationRules, let inherited = inheritedIndent(forLine: target, lineContent: { lines[$0] }, honorIntentional: false) {
            action = inherited.action
            indentation = inherited.indentation
        } else if target > 0 {
            var last = target - 1
            while last >= 0, lines[last].allSatisfy(\.isWhitespace) { last -= 1 }
            guard last >= 0 else { return nil }
            if let expected = enterAction(before: lines[last], after: "", previousLine: last > 0 ? lines[last - 1] : "") {
                indentation = expected.indentation
                action = expected.action == .indentOutdent ? .indent : expected.action
            }
        }
        if let action {
            if action == .indent { indentation = shift(indentation) }
            if action == .outdent { indentation = unshift(indentation) }
            indentation = normalize(indentation)
        }
        return indentation.isEmpty ? nil : indentation
    }

    private mutating func backspace() {
        if column == 0 {
            guard row > 0 else { return }
            let trims = trimCandidates(excluding: [row, row - 1])
            let editRow = row
            column = lines[row - 1].count
            lines[row - 1] += lines[row]
            lines.remove(at: row)
            row -= 1
            autoWhitespaceRows = []
            applyTrims(trims, editRow: editRow, delta: -1)
            return
        }
        let trims = trimCandidates(excluding: [row])
        defer { autoWhitespaceRows = []; applyTrims(trims, editRow: row, delta: 0) }
        let line = lines[row]
        let firstNonWhitespace = line.firstIndex { !$0.isWhitespace }.map { line.distance(from: line.startIndex, to: $0) } ?? line.count
        if column <= firstNonWhitespace {
            let from = visibleWidth(beforeCursor)
            let to = from > 0 ? (from - 1) / profile.tabSize * profile.tabSize : 0
            var target = 0
            var width = 0
            for character in beforeCursor {
                if width >= to { break }
                width = advance(width, by: character)
                target += 1
            }
            lines[row] = String(line.prefix(target)) + afterCursor
            column = target
        } else {
            lines[row] = String(line.prefix(column - 1)) + afterCursor
            column -= 1
        }
    }

    // MARK: Auto whitespace

    private func isAutoWhitespace(_ line: String) -> Bool { !line.isEmpty && line.allSatisfy(\.isWhitespace) }

    /// Rows whose auto-inserted whitespace this edit removes: every registered row the edit does not
    /// touch. Enter at the end of a registered row counts as not touching it, so that row is trimmed too.
    private func trimCandidates(excluding touched: Set<Int>) -> [Int] {
        autoWhitespaceRows.filter { !touched.contains($0) }.sorted()
    }

    /// Rows below the edited one have moved by delta lines (positive for Enter, negative for a join).
    private mutating func applyTrims(_ rows: [Int], editRow: Int, delta: Int) {
        for candidate in rows {
            let index = candidate > editRow ? candidate + delta : candidate
            guard index >= 0, index < lines.count, index != row, isAutoWhitespace(lines[index]) else { continue }
            lines[index] = ""
        }
    }

    // MARK: Indentation arithmetic

    func leadingWhitespace(_ text: String) -> String { String(text.prefix { $0 == " " || $0 == "\t" }) }

    private func advance(_ width: Int, by character: Character) -> Int {
        character == "\t" ? (width / profile.tabSize + 1) * profile.tabSize : width + 1
    }

    func visibleWidth(_ text: String) -> Int { text.reduce(0) { advance($0, by: $1) } }

    private func indentation(levels: Int) -> String {
        guard levels > 0 else { return "" }
        return profile.insertSpaces ? String(repeating: " ", count: levels * profile.tabSize) : String(repeating: "\t", count: levels)
    }

    /// Rewrite the leading whitespace with the configured tab size and style, keeping any text after it.
    func normalize(_ text: String) -> String {
        let whitespace = leadingWhitespace(text)
        let width = visibleWidth(whitespace)
        let normalized: String
        if profile.insertSpaces { normalized = String(repeating: " ", count: width) }
        else { normalized = String(repeating: "\t", count: width / profile.tabSize) + String(repeating: " ", count: width % profile.tabSize) }
        return normalized + text.dropFirst(whitespace.count)
    }

    func shift(_ text: String) -> String {
        indentation(levels: visibleWidth(leadingWhitespace(text)) / profile.tabSize + 1)
    }

    func unshift(_ text: String) -> String {
        let width = visibleWidth(leadingWhitespace(text))
        return indentation(levels: max((width + profile.tabSize - 1) / profile.tabSize - 1, 0))
    }
}
