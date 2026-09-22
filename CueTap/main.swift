import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let wantsJSON = arguments.contains("--json")
func emit(_ response: ControlResponse) {
    if wantsJSON {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(response) { print(String(decoding: data, as: UTF8.self)) }
    } else {
        var text = response.message
        if let status = response.status {
            text += "\nRunning: \(status.running ? "yes" : "no"), state: \(status.state), hotkey: \(status.hotkey)"
            if let name = status.configurationName { text += "\nConfiguration: \(name), \(status.actionCount) actions, position \(status.position)" }
            text += "\nAdvance shortcut: \(status.advanceShortcut)"
            if status.segmentCount > 0 { text += "\nSegment: \(status.segmentIndex)/\(status.segmentCount), phase: \(status.phase), segment position: \(status.segmentPosition)/\(status.segmentActionCount)" }
            if let id = status.configurationID { text += "\nID: \(id)" }
            if let description = status.configurationDescription, !description.isEmpty { text += "\nDescription: \(description)" }
            if let path = status.configurationPath { text += "\nFile: \(path)" }
        }
        if let configurations = response.configurations {
            if configurations.isEmpty { text += "\nNo saved configurations." }
            for configuration in configurations {
                text += "\n\(configuration.selected ? "*" : " ") \(configuration.id): \(configuration.name) (\(configuration.actionCount) actions)"
                if let error = configuration.error { text += "\n  Invalid: \(error)" }
                if !configuration.description.isEmpty { text += "\n  \(configuration.description)" }
            }
        }
        if let path = response.outputPath { text += "\n\(response.compile == nil ? "Exported" : "Compiled") file: \(path)" }
        if let compile = response.compile {
            text += "\nProfile: \(compile.profile), rules: \(compile.rulesSource), tab size \(compile.tabSize), \(compile.insertSpaces ? "spaces" : "tabs")"
            for segment in compile.segments {
                text += "\n  \(segment.name): \(segment.actions) actions, \(segment.lines) lines from \(segment.source)"
                if segment.droppedTrailingNewline { text += " (final newline not typed)" }
            }
            for finding in compile.settings { text += "\n  [\(finding.severity)] \(finding.key): expected \(finding.expected), actual \(finding.actual). \(finding.note)" }
        }
        if let comparison = response.comparison, !comparison.identical {
            text += "\nExpected: \(comparison.expected ?? "(no line)")\nActual:   \(comparison.actual ?? "(no line)")"
        }
        if let diagnostics = response.diagnostics {
            text += "\nExecutable: \(diagnostics.executable)\nPermission scope: \(diagnostics.permissionsScope)"
            for finding in diagnostics.findings {
                text += "\n[\(finding.severity)] \(finding.message)"
                if let suggestion = finding.suggestion { text += "\n  \(suggestion)" }
            }
        }
        if response.ok { print(text) }
        else { FileHandle.standardError.write(Data(("CueTap: " + text + "\n").utf8)) }
    }
}
let executable = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath()
let options: CommandOptions
do { options = try CommandOptions(arguments: arguments, executableURL: executable) }
catch { emit(.failure(error)); exit(2) }
do {
    let response = try CommandRunner(executable: executable, paths: RuntimePaths()).execute(options)
    emit(response)
    if !response.ok { exit(1) }
} catch { emit(.failure(error)); exit(1) }
