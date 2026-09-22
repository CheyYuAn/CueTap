import Foundation

/// One entry of the generated JSON: a text run or a repeated key.
enum ActionEntry: Equatable {
    case text(String)
    case key(String, Int)
}

/// Turns target text into the keystrokes that produce it in an editor described by a profile.
/// Pairs are typed as both halves and a step back inside, tags as an empty element with the
/// attributes filled in afterwards; indentation is left to the editor and corrected with Tab or
/// Backspace only when the editor's prediction differs from the target; a closing bracket or tag the
/// editor already holds is walked over with Right instead of typed. The result is replayed through
/// the editor model before it is returned, so a sequence that would not reproduce the target is a
/// compile failure rather than a surprise during the demo.
struct KeystrokeCompiler {
    let profile: EditorProfile

    struct Segment {
        let name: String
        let entries: [ActionEntry]
        let actionCount: Int
        let lineCount: Int
        let droppedTrailingNewline: Bool
    }

    func compile(_ source: String, name: String) throws -> Segment {
        var text = source.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var dropped = false
        if text.hasSuffix("\n") { text.removeLast(); dropped = true }
        let characters = Array(text)
        try checkCharacters(characters, name: name)
        let analysis = SourceLexer(rules: profile.rules, tags: profile.tags, embedded: profile.embedded).analyze(characters)
        var session = Session(profile: profile, characters: characters, analysis: analysis)
        let lineCount = characters.filter { $0 == "\n" }.count + 1
        var position = 0
        var lineNumber = 1
        while position <= characters.count {
            let lineEnd = characters[position...].firstIndex(of: "\n") ?? characters.count
            let whitespace = String(characters[position..<lineEnd].prefix { $0 == " " || $0 == "\t" })
            let contentStart = position + whitespace.count
            if lineNumber > 1 {
                // Nothing left to type when the editor already holds the rest of the target verbatim,
                // typically the closing brackets or tags of the outermost blocks.
                if session.finished(from: position - 1) { break }
                try session.breakLine(contentStart: contentStart, lineNumber: lineNumber)
            }
            let isLast = lineEnd == characters.count
            if lineEnd == position, !isLast {
                position = lineEnd + 1
                lineNumber += 1
                continue
            }
            try session.adjustIndentation(to: whitespace, lineNumber: lineNumber)
            let stop = try session.typeRange(contentStart, lineEnd, lineNumber: &lineNumber)
            if session.done || stop >= characters.count { break }
            position = stop + 1
            lineNumber += 1
        }
        let produced = session.editor.text
        if produced != text {
            let comparison = TextComparison.compare(expected: text, actual: produced)
            throw ControlError("compile_failed", "\(name): the planned keystrokes do not reproduce the target at line \(comparison.line ?? 0), column \(comparison.column ?? 0). Expected \(comparison.expected.map { "\"\($0)\"" } ?? "no line"), the editor model produced \(comparison.actual.map { "\"\($0)\"" } ?? "no line"). The editor rules may not match this editor; compare a real run with cuetap diff.")
        }
        return Segment(name: name, entries: session.entries, actionCount: session.actionCount, lineCount: lineCount, droppedTrailingNewline: dropped)
    }

    private func checkCharacters(_ characters: [Character], name: String) throws {
        var problems: [String] = []
        var line = 1, column = 1
        for character in characters {
            if character == "\n" { line += 1; column = 1; continue }
            if character != "\t", USKeyboardLayout.stroke(for: character) == nil {
                let scalars = character.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
                problems.append("line \(line) column \(column): \(character) (\(scalars))")
            }
            column += 1
        }
        guard problems.isEmpty else {
            throw ControlError("unsupported_character", "\(name) contains \(problems.count) character(s) CueTap cannot type; only printable ASCII, newline and tab are supported. Ask the user how to replace them: " + problems.prefix(20).joined(separator: "; ") + (problems.count > 20 ? "; ..." : ""))
        }
    }

    /// The editor model, the entries produced so far, and the emitters that keep both in step.
    private struct Session {
        var editor: VirtualEditor
        let characters: [Character]
        let analysis: SourceLexer.Analysis
        var entries: [ActionEntry] = []
        var actionCount = 0
        var done = false
        private var startNewText = true

        init(profile: EditorProfile, characters: [Character], analysis: SourceLexer.Analysis) {
            editor = VirtualEditor(profile: profile)
            self.characters = characters
            self.analysis = analysis
        }

        /// True when everything from this target position on is already in the editor after the cursor
        /// and continues onto later lines. Pending closers on the current line are still stepped over,
        /// the way a person finishes the line; only travel to lines that need no typing is skipped.
        func finished(from position: Int) -> Bool {
            guard position < characters.count, characters[position...].contains("\n") else { return false }
            return editor.remainder == String(characters[position...])
        }

        mutating func emitCharacter(_ character: Character) {
            editor.apply(.character(character))
            actionCount += 1
            if !startNewText, case .text(let value) = entries.last { entries[entries.count - 1] = .text(value + String(character)) }
            else { entries.append(.text(String(character))) }
            startNewText = false
        }

        /// Both halves of a pair as one entry, then a step back inside.
        mutating func emitPair(open: String, close: String, stepBack: Int? = nil) {
            for character in open + close { editor.apply(.character(character)); actionCount += 1 }
            entries.append(.text(open + close))
            emitKey(.left, count: stepBack ?? close.count)
        }

        mutating func emitKey(_ action: DemoAction, count: Int = 1) {
            guard count > 0 else { return }
            let name: String
            switch action {
            case .left: name = "left"
            case .right: name = "right"
            case .enter: name = "enter"
            case .tab: name = "tab"
            case .backspace: name = "backspace"
            case .character: return
            }
            for _ in 0..<count { editor.apply(action) }
            actionCount += count
            if case .key(let last, let existing) = entries.last, last == name { entries[entries.count - 1] = .key(name, existing + count) }
            else { entries.append(.key(name, count)) }
            startNewText = true
        }

        /// Type the target from start up to end, one line or one attribute list at a time. Returns
        /// where typing stopped: the given end, or the end of a later line when an opening tag spread
        /// over several lines was consumed on the way.
        @discardableResult
        mutating func typeRange(_ start: Int, _ end: Int, lineNumber: inout Int) throws -> Int {
            var position = start
            var end = end
            while position < end, !done {
                let character = characters[position]
                if character == "\n" {
                    // A line break inside an opening tag: the editor keeps the indentation, and the
                    // attribute line is brought to the target's depth like any other line.
                    emitKey(.enter)
                    lineNumber += 1
                    let whitespace = String(characters[(position + 1)...].prefix { $0 == " " || $0 == "\t" })
                    try adjustIndentation(to: whitespace, lineNumber: lineNumber)
                    position += 1 + whitespace.count
                    continue
                }
                if let tag = analysis.openingTags[position] {
                    // The element as an empty pair first, then back inside the opening tag for its
                    // attributes, then over the > for the content.
                    let openText = String(characters[position..<tag.attributesStart]) + ">"
                    let closeText = String(characters[tag.closeStart...tag.closeEnd])
                    let hasAttributes = tag.attributesStart < tag.openEnd
                    emitPair(open: openText, close: closeText, stepBack: closeText.count + (hasAttributes ? 1 : 0))
                    if hasAttributes {
                        try typeRange(tag.attributesStart, tag.openEnd, lineNumber: &lineNumber)
                        emitKey(.right)
                    }
                    position = tag.openEnd + 1
                    end = max(end, characters[position...].firstIndex(of: "\n") ?? characters.count)
                    continue
                }
                if let closeEnd = analysis.closingTags[position] {
                    if finished(from: position) { done = true; return end }
                    try stepOverPending(String(characters[position...closeEnd]), lineNumber: lineNumber)
                    position = closeEnd + 1
                    continue
                }
                if let closer = analysis.closerOf[position], closer == position + 1 {
                    // An empty pair is typed straight through; there is nothing to go back for.
                    emitCharacter(character)
                    emitCharacter(characters[closer])
                    position = closer + 1
                    continue
                }
                if let closer = analysis.closerOf[position] {
                    emitPair(open: String(character), close: String(characters[closer]))
                } else if analysis.openerOf[position] != nil {
                    if finished(from: position) { done = true; return end }
                    try stepOverPending(String(character), lineNumber: lineNumber)
                } else {
                    guard character != "\t" else {
                        throw ControlError("unsupported_tab", "line \(lineNumber): a tab outside the indentation cannot be typed, because the editor turns Tab into spaces up to the next stop.")
                    }
                    emitCharacter(character)
                }
                position += 1
            }
            return end
        }

        /// A closing symbol whose opener was typed as a pair is already after the cursor; walk over it.
        mutating func stepOverPending(_ close: String, lineNumber: Int) throws {
            guard editor.afterCursor.hasPrefix(close) else {
                let ahead = editor.remainder.prefix(20)
                throw ControlError("compile_failed", "line \(lineNumber): expected the pending \(close) right after the cursor, but the editor model has \"\(ahead)\" there. This layout is not supported yet.")
            }
            emitKey(.right, count: close.count)
        }

        /// Move to the next target line. When the editor already holds the next line, because it
        /// pushed a closing bracket or tag there, walk to it instead of inserting another line.
        mutating func breakLine(contentStart: Int, lineNumber: Int) throws {
            var pending: String?
            if let closeEnd = analysis.closingTags[contentStart] { pending = String(characters[contentStart...closeEnd]) }
            else if analysis.openerOf[contentStart] != nil { pending = String(characters[contentStart]) }
            if let pending, editor.afterCursor.isEmpty, editor.row + 1 < editor.lines.count {
                let next = editor.lines[editor.row + 1]
                let whitespace = editor.leadingWhitespace(next)
                if next.dropFirst(whitespace.count).hasPrefix(pending) {
                    while !editor.beforeCursor.isEmpty, editor.beforeCursor.allSatisfy(\.isWhitespace) { emitKey(.backspace) }
                    emitKey(.right, count: 1 + whitespace.count)
                    return
                }
            }
            emitKey(.enter)
        }

        /// Bring the current line's indentation to the target's with Tab or Backspace at the line start.
        mutating func adjustIndentation(to target: String, lineNumber: Int) throws {
            var steps = 0
            while editor.beforeCursor != target {
                let current = editor.beforeCursor
                guard current.allSatisfy(\.isWhitespace) else {
                    throw ControlError("compile_failed", "line \(lineNumber): the cursor is not at the start of a line, so indentation cannot be adjusted.")
                }
                let have = editor.visibleWidth(current), want = editor.visibleWidth(target)
                guard have != want else {
                    throw ControlError("compile_failed", "line \(lineNumber): the target indents with \(target.contains("\t") ? "tabs" : "spaces") but the profile is set to \(editor.profile.insertSpaces ? "spaces" : "tabs"). Use --tabs or --tab-size to match the editor.")
                }
                let before = (editor.text, editor.row, editor.column)
                emitKey(have < want ? .tab : .backspace)
                steps += 1
                let after = (editor.text, editor.row, editor.column)
                guard steps < 64, before != after else {
                    throw ControlError("compile_failed", "line \(lineNumber): the editor model cannot reach the target indentation from \(have) to \(want) columns.")
                }
            }
        }
    }
}

/// Renders compiled segments as a version 2 configuration in the same layout as hand-written files.
enum ConfigurationWriter {
    static func render(name: String, description: String, segments: [(name: String, description: String, entries: [ActionEntry])]) -> String {
        var output = "{\n  \"version\": 2,\n  \"name\": \(quote(name)),\n  \"description\": \(quote(description)),\n  \"segments\": [\n"
        for (index, segment) in segments.enumerated() {
            output += "    {\n      \"name\": \(quote(segment.name)),\n      \"description\": \(quote(segment.description)),\n      \"actions\": [\n"
            for (position, entry) in segment.entries.enumerated() {
                switch entry {
                case .text(let value): output += "        { \"type\": \"text\", \"value\": \(quote(value)) }"
                case .key(let key, let count):
                    output += count == 1 ? "        { \"type\": \"key\", \"key\": \"\(key)\" }" : "        { \"type\": \"key\", \"key\": \"\(key)\", \"count\": \(count) }"
                }
                output += position == segment.entries.count - 1 ? "\n" : ",\n"
            }
            output += "      ]\n    }" + (index == segments.count - 1 ? "\n" : ",\n")
        }
        return output + "  ]\n}\n"
    }

    static func quote(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes]) else { return "\"\"" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// What a compile produced, returned with the response.
struct CompileReport: Codable {
    struct SegmentReport: Codable {
        let name: String
        let source: String
        let lines: Int
        let actions: Int
        let droppedTrailingNewline: Bool
    }
    let profile: String
    let rulesSource: String
    let tabSize: Int
    let insertSpaces: Bool
    let tags: Bool
    let actionCount: Int
    let segments: [SegmentReport]
    let settingsFile: String?
    let settings: [SettingsFinding]
}

struct CompileOptions {
    var profile: String?
    var rulesPath: String?
    var tabSize = 4
    var insertSpaces = true
    var tags: Bool?
    var output: String?
    var name: String?
    var description: String?
    var force = false
    var targets: [String] = []

    static let usage = "Usage: cuetap compile --profile vscode-LANGUAGE | --rules FILE [--tab-size N] [--tabs] [--tags | --no-tags] --output FILE [--name NAME] [--description TEXT] [--force] TARGET..."

    init(arguments: [String]) throws {
        var args = arguments
        while !args.isEmpty {
            let arg = args.removeFirst()
            func value() throws -> String {
                guard !args.isEmpty, !args[0].hasPrefix("--") else { throw ScriptError("\(arg) needs a value. \(Self.usage)") }
                return args.removeFirst()
            }
            switch arg {
            case "--profile": profile = try value()
            case "--rules": rulesPath = try value()
            case "--output": output = try value()
            case "--name": name = try value()
            case "--description": description = try value()
            case "--tab-size":
                guard let size = Int(try value()), size > 0, size <= 16 else { throw ScriptError("--tab-size needs a number from 1 to 16.") }
                tabSize = size
            case "--tabs": insertSpaces = false
            case "--tags": tags = true
            case "--no-tags": tags = false
            case "--force": force = true
            default:
                guard !arg.hasPrefix("--") else { throw ScriptError("Unknown option \(arg). \(Self.usage)") }
                targets.append(arg)
            }
        }
        guard profile != nil || rulesPath != nil else { throw ScriptError("compile needs --profile vscode-LANGUAGE or --rules FILE, for example \(EditorProfile.exampleNames.joined(separator: ", ")).") }
        guard output != nil else { throw ScriptError("compile needs --output FILE. \(Self.usage)") }
        guard !targets.isEmpty else { throw ScriptError("compile needs at least one target text file. \(Self.usage)") }
    }
}

/// The compile command: read targets, compile each into a segment, validate the JSON and write it.
struct CompileCommand {
    let options: CompileOptions

    func run() throws -> ControlResponse {
        let profile = try EditorProfile.resolve(name: options.profile, rulesPath: options.rulesPath, tabSize: options.tabSize, insertSpaces: options.insertSpaces, tags: options.tags)
        let output = URL(fileURLWithPath: (options.output! as NSString).expandingTildeInPath).standardizedFileURL
        if FileManager.default.fileExists(atPath: output.path), !options.force {
            throw ControlError("output_exists", "\(output.path) already exists. Choose another --output or pass --force to replace it.")
        }
        let compiler = KeystrokeCompiler(profile: profile)
        var segments: [(name: String, description: String, entries: [ActionEntry])] = []
        var reports: [CompileReport.SegmentReport] = []
        for target in options.targets {
            let url = URL(fileURLWithPath: (target as NSString).expandingTildeInPath).standardizedFileURL
            let source: String
            do { source = try String(contentsOf: url, encoding: .utf8) }
            catch { throw ControlError("target_unreadable", "Cannot read \(url.path) as UTF-8 text: \(error)") }
            let stem = url.deletingPathExtension().lastPathComponent
            let compiled = try compiler.compile(source, name: url.lastPathComponent)
            segments.append((stem, "", compiled.entries))
            reports.append(CompileReport.SegmentReport(name: stem, source: url.path, lines: compiled.lineCount, actions: compiled.actionCount, droppedTrailingNewline: compiled.droppedTrailingNewline))
        }
        let name = options.name ?? segments[0].name
        let rendered = ConfigurationWriter.render(name: name, description: options.description ?? "", segments: segments)
        let data = Data(rendered.utf8)
        let script = try DemoScript.decode(data)
        do { try data.write(to: output, options: .atomic) }
        catch { throw ControlError("output_unwritable", "Cannot write \(output.path): \(error)") }
        let check = EditorSettingsCheck.vsCode(profile: profile, targets: options.targets.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) })
        let report = CompileReport(profile: profile.name, rulesSource: profile.rulesSource, tabSize: profile.tabSize, insertSpaces: profile.insertSpaces, tags: profile.tags,
                                   actionCount: script.actions.count, segments: reports, settingsFile: check.file, settings: check.findings)
        var message = "Compiled \(name): \(script.actions.count) actions in \(segments.count) segment(s) using \(profile.name) rules from \(profile.rulesSource)."
        let warnings = check.findings.filter { $0.severity == "warning" }.count
        if warnings > 0 { message += " \(warnings) editor setting(s) need attention before the demo; see settings." }
        var response = ControlResponse(message: message, outputPath: output.path)
        response.compile = report
        return response
    }
}
