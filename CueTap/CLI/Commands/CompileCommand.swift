import Foundation

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
        let check: (file: String?, findings: [SettingsFinding]) = profile.plain ? (nil, [])
            : EditorSettingsCheck.vsCode(profile: profile, targets: options.targets.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) })
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
