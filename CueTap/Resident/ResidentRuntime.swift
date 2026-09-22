import AppKit
import Carbon
import CoreGraphics

final class ResidentRuntime {
    private let paths: RuntimePaths
    private let executable: URL
    private var settings: RuntimeSettings
    private var script: DemoScript
    private var scriptURL: URL
    private let initialFile: DemoScript.File
    private let session: KeyboardSession
    private var server: LocalControl?
    private var menu: StatusMenu?

    init(options: CommandOptions, executable: URL, paths: RuntimePaths) throws {
        self.paths = paths
        self.executable = executable
        settings = try paths.read()
        let saved = settings.configurationPath.map { URL(fileURLWithPath: $0) }
        scriptURL = options.explicitScript ? options.scriptURL : saved ?? options.scriptURL
        // Only the untouched bundled example may fall back to the compiled-in copy; a chosen file
        // that has gone missing must still fail loudly instead of silently reverting to the example.
        initialFile = options.explicitScript || saved != nil
            ? try DemoScript.readFile(from: scriptURL)
            : try DemoScript.readBundledExample(at: scriptURL).file
        script = initialFile.script
        session = KeyboardSession(segments: script.segments, hotkey: try DemoHotkey(settings.hotkey),
                                  advanceShortcut: try SegmentAdvanceShortcut(settings.advanceShortcut))
    }

    static func permissions() -> PermissionStatus {
        PermissionStatus(listen: CGPreflightListenEventAccess(), post: CGPreflightPostEventAccess(),
                         secureInput: IsSecureEventInputEnabled(), englishInputSource: (try? SystemInputSourceAccess().englishID()) != nil)
    }

    func run() throws {
        // Reserve the control endpoint before creating any global keyboard interceptor.
        server = try LocalControl(name: paths.portName) { [weak self] request in
            guard let self else { return .failure(ControlError("shutting_down", "CueTap is shutting down.")) }
            return self.handle(request)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        menu = try StatusMenu(
            configurations: { [weak self] in
                guard let self else { return [] }
                return try ConfigurationStore(paths: self.paths).list(selectedPath: self.scriptURL.path)
            },
            select: { [weak self] id in
                guard let self else { return .failure(ControlError("shutting_down", "CueTap is shutting down.")) }
                do { return self.handle(ControlRequest(command: "config", configuration: try ConfigurationCommand(arguments: ["use", id]))) }
                catch { return .failure(error) }
            },
            openFolder: { [weak self] in
                guard let self else { return }
                NSWorkspace.shared.open(self.paths.configurations)
            },
            loginEnabled: { [weak self] in
                guard let self else { return false }
                return LoginItem(executable: self.executable).isEnabled
            },
            setLogin: { [weak self] enabled in
                guard let self else { return .failure(ControlError("shutting_down", "CueTap is shutting down.")) }
                do {
                    try LoginItem(executable: self.executable).setEnabled(enabled)
                    return ControlResponse(message: enabled ? "CueTap starts at login." : "CueTap no longer starts at login.")
                } catch { return .failure(error) }
            },
            stop: { [weak self] in
                guard let self else { return }
                _ = self.handle(ControlRequest(command: "stop"))
            },
            quit: { [weak self] in self?.session.stop() })
        session.onChange = { [weak self] in self?.refreshMenu() }
        session.onStop = {
            app.stop(nil)
            if let event = NSEvent.otherEvent(with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0,
                                              windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0) {
                app.postEvent(event, atStart: true)
            }
        }
        try session.start()
        do {
            // This also migrates a legacy external path and imports the bundled default once.
            let selection = try ConfigurationStore(paths: paths).select(initialFile, from: scriptURL, settings: settings)
            scriptURL = selection.url
            settings = selection.settings
        } catch { session.stop(); throw error }
        refreshMenu()
        print("Loaded: \(script.name), \(script.actions.count) actions.\nFile: \(scriptURL.path)")
        app.run()
        menu = nil
        server = nil
        if let failure = session.failure { throw ControlError("runtime_failed", failure) }
    }

    private func refreshMenu() {
        menu?.update(active: session.state != .off, name: script.name,
                     segment: session.segmentIndex + 1, count: script.segments.count,
                     hotkey: settings.hotkey, advance: settings.advanceShortcut,
                     canSelect: session.state == .off)
    }

    private func status() -> RuntimeStatus {
        let permissions = Self.permissions()
        return RuntimeStatus(running: true, pid: ProcessInfo.processInfo.processIdentifier, executable: executable.path,
                             state: session.state == .off ? "off" : "on", phase: String(describing: session.state),
                             ready: permissions.ready && session.failure == nil, configurationName: script.name,
                             configurationPath: scriptURL.path,
                             configurationID: ConfigurationStore(paths: paths).id(for: scriptURL),
                             configurationDescription: script.description,
                             actionCount: script.actions.count,
                             position: session.position, hotkey: settings.hotkey, permissions: permissions,
                             advanceShortcut: settings.advanceShortcut, segmentCount: script.segments.count,
                             segmentIndex: session.segmentIndex + 1, segmentName: session.segmentName,
                             segmentPosition: session.segmentPosition, segmentActionCount: session.segmentActionCount)
    }

    private func handle(_ request: ControlRequest) -> ControlResponse {
        do {
            switch request.command {
            case "status", "hotkeyGet", "advanceGet": break
            case "config":
                guard let command = request.configuration else { throw ControlError("invalid_request", "Missing configuration command.") }
                let store = ConfigurationStore(paths: paths)
                if [.list, .export].contains(command.operation) {
                    var response = try store.listOrExport(command, selectedPath: scriptURL.path)
                    response.status = status()
                    return response
                }
                guard session.canReconfigure else { throw ControlError("busy", "Stop the demo and release all keys before changing saved configurations.") }
                guard let selector = command.selector else { throw ControlError("invalid_request", "Missing configuration ID or name.") }
                let url = try store.resolve(selector)
                switch command.operation {
                case .use:
                    let selection = try store.select(from: url, settings: settings)
                    try session.configure(segments: selection.script.segments, hotkey: DemoHotkey(selection.settings.hotkey), advanceShortcut: SegmentAdvanceShortcut(selection.settings.advanceShortcut))
                    settings = selection.settings
                    script = selection.script
                    scriptURL = selection.url
                case .rename:
                    guard let name = command.value else { throw ControlError("invalid_request", "Missing configuration name.") }
                    let renamed = try store.rename(url, to: name)
                    if url.resolvingSymlinksInPath().path == scriptURL.resolvingSymlinksInPath().path {
                        try session.configure(segments: renamed.segments, hotkey: DemoHotkey(settings.hotkey), advanceShortcut: SegmentAdvanceShortcut(settings.advanceShortcut))
                        script = renamed
                    }
                case .remove: try store.remove(url, selectedPath: scriptURL.path)
                case .list, .export: break
                }
                refreshMenu()
                return ControlResponse(message: "Configuration \(command.operation.rawValue) completed.", status: status())
            case "load", "reload", "hotkeySet", "advanceSet":
                guard session.canReconfigure else { throw ControlError("busy", "Stop the demo and release all keys before changing the configuration or hotkey.") }
                var nextSettings = settings
                var nextScript = script
                var nextURL = scriptURL
                if request.command == "advanceSet" {
                    guard let value = request.value else { throw ControlError("invalid_request", "Missing advance shortcut.") }
                    nextSettings.advanceShortcut = try SegmentAdvanceShortcut(value).label
                    try paths.save(nextSettings)
                } else if request.command == "hotkeySet" {
                    guard let value = request.value else { throw ControlError("invalid_request", "Missing hotkey.") }
                    nextSettings.hotkey = try DemoHotkey(value).label
                    try paths.save(nextSettings)
                } else {
                    if request.command == "load" {
                        guard let value = request.value, value.hasPrefix("/") else { throw ControlError("invalid_request", "Configuration path must be absolute.") }
                        nextURL = URL(fileURLWithPath: value)
                    }
                    let selection = try ConfigurationStore(paths: paths).select(from: nextURL, settings: nextSettings)
                    nextScript = selection.script
                    nextURL = selection.url
                    nextSettings = selection.settings
                }
                // All validation precedes persistence and mutation. This handler and the tap are serial.
                try session.configure(segments: nextScript.segments, hotkey: DemoHotkey(nextSettings.hotkey), advanceShortcut: SegmentAdvanceShortcut(nextSettings.advanceShortcut))
                settings = nextSettings
                script = nextScript
                scriptURL = nextURL
                refreshMenu()
            case "stop": try session.stopDemo()
            case "quit":
                // Reply before stopping AppKit's event loop.
                DispatchQueue.main.async { [weak self] in self?.session.stop() }
            default: throw ControlError("unknown_command", "Unknown control command.")
            }
            return ControlResponse(message: request.command == "quit" ? "Quit request accepted." : "Operation completed.", status: status())
        } catch { return .failure(error) }
    }
}
