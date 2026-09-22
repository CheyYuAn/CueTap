import Foundation

/// Renders a control response as the plain text a person reads in the terminal; `--json` bypasses this.
enum ResponseFormatter {
    static func text(_ response: ControlResponse) -> String {
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
        for profile in response.profiles ?? [] {
            text += "\n\(profile.name) [\(profile.source)]\(profile.tags ? " tags" : "")\(profile.extensions.isEmpty ? "" : " " + profile.extensions.joined(separator: " "))"
    }
        for result in response.comparisons ?? [] where !result.comparison.identical {
            text += "\n\(result.actual) vs \(result.expected): line \(result.comparison.line ?? 0), column \(result.comparison.column ?? 0)\nExpected: \(result.comparison.expected ?? "(no line)")\nActual:   \(result.comparison.actual ?? "(no line)")"
    }
        if let diagnostics = response.diagnostics {
            text += "\nExecutable: \(diagnostics.executable)\nPermission scope: \(diagnostics.permissionsScope)"
            for finding in diagnostics.findings {
                text += "\n[\(finding.severity)] \(finding.message)"
                if let suggestion = finding.suggestion { text += "\n  \(suggestion)" }
            }
    }
        return text
    }
}
