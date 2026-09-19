import Foundation
import Darwin

struct RuntimeSettings: Codable {
    var configurationPath: String?
    var hotkey = DemoHotkey.default.label
    var advanceShortcut = SegmentAdvanceShortcut.default.label

    enum CodingKeys: String, CodingKey { case configurationPath, hotkey, advanceShortcut }
    init(configurationPath: String? = nil, hotkey: String = DemoHotkey.default.label,
         advanceShortcut: String = SegmentAdvanceShortcut.default.label) {
        self.configurationPath = configurationPath; self.hotkey = hotkey; self.advanceShortcut = advanceShortcut
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        configurationPath = try values.decodeIfPresent(String.self, forKey: .configurationPath)
        hotkey = try values.decodeIfPresent(String.self, forKey: .hotkey) ?? DemoHotkey.default.label
        advanceShortcut = try values.decodeIfPresent(String.self, forKey: .advanceShortcut) ?? SegmentAdvanceShortcut.default.label
    }
}

struct RuntimePaths {
    let directory: URL
    let logDirectory: URL
    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        if let override = environment["CUETAP_HOME"] {
            directory = URL(fileURLWithPath: override).standardizedFileURL
            logDirectory = directory.appendingPathComponent("logs", isDirectory: true)
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("CueTap", isDirectory: true)
            logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Logs/CueTap", isDirectory: true)
        }
    }
    var settings: URL { directory.appendingPathComponent("settings.json") }
    var configurations: URL { directory.appendingPathComponent("configurations", isDirectory: true) }
    var log: URL { logDirectory.appendingPathComponent("runtime.log") }
    var portName: String {
        // Stable across processes; isolate explicit test/user profiles without network ports.
        let hash = directory.path.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return "local.cuetap.\(getuid()).\(String(hash, radix: 16))"
    }
    func prepare() throws {
        try prepareDirectory(directory)
    }
    func prepareConfigurations() throws {
        try prepare()
        try prepareDirectory(configurations)
    }
    func prepareLog() throws {
        try prepareDirectory(logDirectory)
        let legacy = directory.appendingPathComponent("runtime.log")
        if FileManager.default.fileExists(atPath: legacy.path) {
            // Preserve the previous version's diagnostics during the one-time directory migration.
            let archive = logDirectory.appendingPathComponent("legacy-runtime-\(UUID().uuidString).log")
            try FileManager.default.moveItem(at: legacy, to: archive)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: archive.path)
        }
    }
    private func prepareDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
    func read() throws -> RuntimeSettings {
        guard FileManager.default.fileExists(atPath: settings.path) else { return RuntimeSettings() }
        do {
            let value = try JSONDecoder().decode(RuntimeSettings.self, from: Data(contentsOf: settings))
            _ = try DemoHotkey(value.hotkey)
            _ = try SegmentAdvanceShortcut(value.advanceShortcut)
            return value
        } catch { throw ControlError("invalid_settings", "Cannot read settings at \(settings.path): \(error)") }
    }
    func save(_ value: RuntimeSettings) throws {
        try prepare()
        try JSONEncoder().encode(value).write(to: settings, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settings.path)
    }
}
