import Foundation

/// Explicit troubleshooting only. No startup, file writes, permission requests or input-source changes.
struct Doctor {
    let executable: URL
    let paths: RuntimePaths
    private let permissions: () -> PermissionStatus
    private let queryResident: () throws -> ControlResponse

    init(executable: URL, paths: RuntimePaths,
         permissions: @escaping () -> PermissionStatus = ResidentRuntime.permissions,
         queryResident: (() throws -> ControlResponse)? = nil) {
        self.executable = executable
        self.paths = paths
        self.permissions = permissions
        self.queryResident = queryResident ?? { try LocalControl.send(ControlRequest(command: "status"), name: paths.portName) }
    }

    func run() -> ControlResponse {
        var findings: [DiagnosticFinding] = []
        var live: RuntimeStatus?
        do {
            let response = try queryResident()
            guard response.ok, let status = response.status, status.running else {
                throw response.error ?? ControlError("invalid_response", "The resident did not return a running status.")
            }
            live = status
            findings.append(DiagnosticFinding(id: "resident", severity: "pass", message: "Resident PID \(status.pid.map(String.init) ?? "unknown") is responding; demo is \(status.state)."))
            findings.append(DiagnosticFinding(id: "listener", severity: status.ready ? "pass" : "error", message: status.ready ? "The resident reports ready." : "The resident is not ready.", suggestion: status.ready ? nil : "Review the permission and input-source findings, then restart if necessary."))
            if response.version != ControlResponse.version || status.executable != executable.path {
                findings.append(DiagnosticFinding(id: "resident_version", severity: "warning", message: "The resident uses \(response.version) at \(status.executable ?? "an unknown path").", suggestion: "When convenient, quit and start with this executable to use version \(ControlResponse.version)."))
            }
        } catch let error as ControlError where error.code == "not_running" {
            findings.append(DiagnosticFinding(id: "resident", severity: "info", message: "CueTap is not running.", suggestion: "Run cuetap start when you want to use it."))
        } catch {
            findings.append(DiagnosticFinding(id: "resident", severity: "error", message: String(describing: error), suggestion: "Inspect the resident process and runtime log. Do not launch another interceptor while the current one may still be running."))
        }

        let scope = live?.permissions == nil ? "command_host" : "resident"
        let access = live?.permissions ?? permissions()
        findings.append(DiagnosticFinding(id: "input_monitoring", severity: access.listen ? "pass" : "error", message: "Input Monitoring (\(scope)): \(access.listen ? "available" : "unavailable").", suggestion: access.listen ? nil : "Authorize the relevant terminal or executable in System Settings > Privacy & Security > Input Monitoring."))
        findings.append(DiagnosticFinding(id: "accessibility", severity: access.post ? "pass" : "error", message: "Accessibility (\(scope)): \(access.post ? "available" : "unavailable").", suggestion: access.post ? nil : "Authorize the relevant terminal or executable in System Settings > Privacy & Security > Accessibility."))
        findings.append(DiagnosticFinding(id: "english_input_source", severity: access.englishInputSource ? "pass" : "error", message: access.englishInputSource ? "ABC or U.S. is enabled." : "No supported English input source is enabled.", suggestion: access.englishInputSource ? nil : "Add ABC or U.S. in System Settings > Keyboard > Input Sources."))
        findings.append(DiagnosticFinding(id: "secure_input", severity: access.secureInput ? "error" : "pass", message: access.secureInput ? "Secure Input is enabled." : "Secure Input is off.", suggestion: access.secureInput ? "Finish or close the secure input session (a password field or the lock screen). A demo cannot run while it is on; the resident keeps waiting." : nil))

        var settings: RuntimeSettings?
        do {
            settings = try paths.read()
            let exists = FileManager.default.fileExists(atPath: paths.settings.path)
            findings.append(DiagnosticFinding(id: "settings", severity: exists ? "pass" : "info", message: exists ? "Settings are readable." : "No saved settings yet; first startup will create them."))
        } catch {
            findings.append(DiagnosticFinding(id: "settings", severity: "error", message: String(describing: error), suggestion: "Repair the settings file at \(paths.settings.path), preserving your configuration path and hotkey."))
        }
        if let settings {
            let selected = live?.configurationPath ?? settings.configurationPath
            let url = selected.map { URL(fileURLWithPath: $0) } ?? DemoScript.bundledExampleURL(besideExecutable: executable)
            do {
                var origin = url.path
                let script: DemoScript
                if let selected { script = try DemoScript.load(from: URL(fileURLWithPath: selected)) }
                else {
                    let example = try DemoScript.readBundledExample(at: url)
                    script = example.file.script
                    if example.isBuiltIn { origin = "the built-in example" }
                }
                findings.append(DiagnosticFinding(id: "configuration", severity: "pass", message: "\(script.name): \(script.actions.count) actions at \(origin)."))
            } catch {
                findings.append(DiagnosticFinding(id: "configuration", severity: "error", message: String(describing: error), suggestion: selected == nil ? "Restore the bundled html-demo.json or start with --script FILE." : "Restore this file or import a valid configuration with load FILE (running) or start --script FILE (stopped)."))
            }
        }
        findings.append(directoryFinding(paths.directory, id: "data_directory"))
        findings.append(directoryFinding(paths.configurations, id: "configuration_directory"))
        findings.append(directoryFinding(paths.logDirectory, id: "log_directory"))
        findings.append(DiagnosticFinding(id: "log", severity: "info", message: "Startup log: \(paths.log.path)."))
        let report = DoctorReport(executable: executable.path, dataDirectory: paths.directory.path,
                                  configurationDirectory: paths.configurations.path, logPath: paths.log.path,
                                  permissionsScope: scope, findings: findings)
        let failed = findings.contains { $0.severity == "error" }
        return ControlResponse(ok: !failed, message: failed ? "Diagnostics found problems." : "Diagnostics completed.", status: live,
                               error: failed ? ControlError("diagnostic_failed", "See diagnostics.findings for details.") : nil,
                               diagnostics: report)
    }

    private func directoryFinding(_ url: URL, id: String) -> DiagnosticFinding {
        let manager = FileManager.default
        var existing = url
        var isDirectory: ObjCBool = false
        while !manager.fileExists(atPath: existing.path, isDirectory: &isDirectory), existing.path != "/" {
            existing.deleteLastPathComponent()
        }
        let usable = isDirectory.boolValue && manager.isReadableFile(atPath: existing.path) && manager.isWritableFile(atPath: existing.path)
        return DiagnosticFinding(id: id, severity: usable ? "pass" : "error",
                                 message: usable ? "Directory is accessible or can be created: \(url.path)." : "Directory is not accessible: \(url.path).",
                                 suggestion: usable ? nil : "Check ownership and read/write permissions at \(existing.path).")
    }
}
