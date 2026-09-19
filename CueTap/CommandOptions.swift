import Foundation

struct CommandOptions {
    enum Mode: String { case run, start, status, check, doctor, config, validate, help, version, load, reload, stop, quit, hotkeyGet, hotkeySet, advanceGet, advanceSet }
    let mode: Mode
    let scriptURL: URL
    let explicitScript: Bool
    let json: Bool
    let hotkey: String?
    let configuration: ConfigurationCommand?

    init(arguments: [String], executableURL: URL) throws {
        var args = arguments
        let jsonCount = args.filter { $0 == "--json" }.count
        guard jsonCount <= 1 else { throw ScriptError("--json may only be specified once.") }
        json = jsonCount == 1
        args.removeAll { $0 == "--json" }
        var selected: Mode = .run
        var configuration: ConfigurationCommand?
        if let first = args.first, !first.hasPrefix("--") {
            args.removeFirst()
            switch first {
            case "serve": selected = .run
            case "config":
                selected = .config
                configuration = try ConfigurationCommand(arguments: args)
                args = []
            case "advance":
                if args == ["get"] { selected = .advanceGet; args = [] }
                else if args.count == 2, args[0] == "set" { selected = .advanceSet; args.removeFirst() }
                else { throw ScriptError("Usage: cuetap advance get | advance set cmd+click") }
            case "hotkey":
                if args == ["get"] { selected = .hotkeyGet; args = [] }
                else if args.count == 2, args[0] == "set" { selected = .hotkeySet; args.removeFirst() }
                else { throw ScriptError("Usage: cuetap hotkey get | hotkey set cmd+shift+r") }
            default:
                guard let mode = Mode(rawValue: first), ![.run, .hotkeyGet, .hotkeySet, .advanceGet, .advanceSet].contains(mode) else {
                    throw ScriptError("Unknown command: \(first). Run cuetap --help for usage.")
                }
                selected = mode
            }
        } else if let first = args.first, ["--help", "--check", "--validate", "--version"].contains(first) {
            selected = Mode(rawValue: String(first.dropFirst(2)))!
            args.removeFirst()
        }
        var path: String?
        var combination: String?
        if selected == .advanceSet {
            combination = try SegmentAdvanceShortcut(args.removeFirst()).label
        } else if selected == .hotkeySet {
            combination = try DemoHotkey(args.removeFirst()).label
        } else if [.validate, .load].contains(selected), args.count == 1, !args[0].hasPrefix("--") {
            path = args.removeFirst()
        }
        // Preserve the original --script PATH --validate order.
        if selected == .run, args.last == "--validate" { selected = .validate; args.removeLast() }
        if !args.isEmpty {
            guard [.run, .start, .validate].contains(selected), args.count == 2,
                  args[0] == "--script", !args[1].isEmpty, !args[1].hasPrefix("--") else {
                throw ScriptError("Invalid arguments. Run cuetap --help for usage.")
            }
            path = args[1]
        }
        if selected == .load && path == nil { throw ScriptError("load requires a configuration file path.") }
        if selected == .run && json { throw ScriptError("Resident mode does not return JSON. Use start --json or status --json.") }
        mode = selected
        hotkey = combination
        self.configuration = configuration
        explicitScript = path != nil
        if let path {
            scriptURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        } else {
            scriptURL = DemoScript.bundledExampleURL(besideExecutable: executableURL)
        }
    }
}
