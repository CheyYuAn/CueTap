import Foundation

struct CommandRunner {
    let executable: URL
    let paths: RuntimePaths

    func execute(_ options: CommandOptions) throws -> ControlResponse {
        switch options.mode {
        case .help: return ControlResponse(message: Self.help)
        case .version: return ControlResponse(message: "CueTap \(ControlResponse.version), control protocol 1, configuration formats 1 and 2.")
        case .doctor: return Doctor(executable: executable, paths: paths).run()
        case .compile:
            guard let compile = options.compile else { throw ControlError("invalid_request", "Missing compile options.") }
            return try CompileCommand(options: compile).run()
        case .profiles:
            return try ProfilesCommand().run()
        case .diff:
            guard !options.diffPairs.isEmpty else { throw ControlError("invalid_request", "Missing diff paths.") }
            return try DiffCommand(pairs: options.diffPairs).run()
        case .config:
            guard let command = options.configuration else { throw ControlError("invalid_request", "Missing configuration command.") }
            do {
                return try LocalControl.send(ControlRequest(command: "config", configuration: command), name: paths.portName)
            } catch let error as ControlError where error.code == "not_running" {
                guard [.list, .export].contains(command.operation) else { throw error }
                return try ConfigurationStore(paths: paths).listOrExport(command, selectedPath: paths.read().configurationPath)
            }
        case .check:
            let permissions = ResidentRuntime.permissions()
            let status = RuntimeStatus(running: false, hotkey: DemoHotkey.default.label, permissions: permissions)
            if !permissions.ready {
                var result = ControlResponse.failure(ControlError("not_ready", "Input Monitoring, Accessibility, ABC/U.S. or Secure Input is not ready. Check System Settings; CueTap does not grant permissions."))
                result.status = status
                return result
            }
            return ControlResponse(message: "Permission and input-source checks passed.", status: status)
        case .validate:
            let script = options.explicitScript ? try DemoScript.load(from: options.scriptURL)
                                              : try DemoScript.readBundledExample(at: options.scriptURL).file.script
            return ControlResponse(message: "Valid configuration: \(script.name), \(script.actions.count) actions.", status:
                RuntimeStatus(running: false, configurationName: script.name, configurationPath: options.scriptURL.path,
                              configurationDescription: script.description,
                              actionCount: script.actions.count, hotkey: DemoHotkey.default.label, segmentCount: script.segments.count))
        case .status, .hotkeyGet, .advanceGet:
            do { return try send(options.mode.rawValue) }
            catch let error as ControlError where error.code == "not_running" {
                let settings = try paths.read()
                return ControlResponse(message: "CueTap is not running.", status:
                    RuntimeStatus(running: false, configurationPath: settings.configurationPath, hotkey: settings.hotkey, advanceShortcut: settings.advanceShortcut))
            }
        case .start: return try start(options)
        case .load: return try send("load", value: options.scriptURL.path)
        case .advanceSet: return try send("advanceSet", value: options.hotkey)
        case .hotkeySet: return try send("hotkeySet", value: options.hotkey)
        case .reload, .stop: return try send(options.mode.rawValue)
        case .quit:
            var response: ControlResponse?
            do { response = try send("quit") }
            catch let error as ControlError where error.code == "not_running" {
                return ControlResponse(message: "CueTap has exited.", status: RuntimeStatus(running: false, hotkey: try paths.read().hotkey))
            }
            catch let error as ControlError where error.code == "ipc_timeout" {
                // Shutdown may invalidate the port before its reply is observed. Confirm disappearance below.
            }
            if let response, !response.ok { return response }
            let deadline = Date().addingTimeInterval(5)
            while Date() < deadline {
                do { _ = try send("status") }
                catch let error as ControlError where error.code == "not_running" {
                    return ControlResponse(message: "CueTap has exited.", status: RuntimeStatus(running: false, hotkey: try paths.read().hotkey))
                }
                catch let error as ControlError where error.code == "ipc_timeout" { }
                Thread.sleep(forTimeInterval: 0.05)
            }
            throw ControlError("shutdown_timeout", "Shutdown was not confirmed. Check status.")
        case .run:
            try ResidentRuntime(options: options, executable: executable, paths: paths).run()
            return ControlResponse(message: "CueTap has exited.")
        }
    }

    private func send(_ command: String, value: String? = nil) throws -> ControlResponse {
        try LocalControl.send(ControlRequest(command: command, value: value), name: paths.portName)
    }

    private func start(_ options: CommandOptions) throws -> ControlResponse {
        do {
            let current = try send("status")
            if options.explicitScript { throw ControlError("already_running", "CueTap is already running. Use load to change configuration.") }
            return current
        } catch let error as ControlError where error.code == "not_running" { }
        // Validate in this process to give immediate useful errors before launching.
        let settings = try paths.read()
        let saved = settings.configurationPath.map { URL(fileURLWithPath: $0) }
        let url = options.explicitScript ? options.scriptURL : saved ?? options.scriptURL
        var usesBuiltIn = false
        if options.explicitScript || saved != nil { _ = try DemoScript.load(from: url) }
        else { usesBuiltIn = try DemoScript.readBundledExample(at: url).isBuiltIn }
        try paths.prepare()
        try paths.prepareLog()
        guard FileManager.default.createFile(atPath: paths.log.path, contents: Data(), attributes: [.posixPermissions: 0o600]) else {
            throw ControlError("log_unavailable", "Cannot create the startup log at \(paths.log.path).")
        }
        let log = try FileHandle(forWritingTo: paths.log)
        defer { try? log.close() }
        let process = Process()
        process.executableURL = executable
        // Passing --script would make the resident demand a file that is not there; leaving it out
        // lets the resident resolve the same bundled example and fall back to the compiled-in copy.
        process.arguments = usesBuiltIn ? ["serve"] : ["serve", "--script", url.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log
        process.standardError = log
        try process.run()
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if !process.isRunning {
                let detail = (try? String(contentsOf: paths.log, encoding: .utf8)) ?? ""
                throw ControlError("start_failed", "Start failed. \(detail)")
            }
            do {
                let response = try send("status")
                if response.ok { return response }
            } catch let error as ControlError where error.code == "not_running" { }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw ControlError("start_timeout", "Start was not confirmed in time. Check status and \(paths.log.path) before retrying.")
    }}
