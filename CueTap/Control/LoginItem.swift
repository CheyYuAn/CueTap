import Foundation

/// Start at login for a plain command-line tool: a LaunchAgent property list in the user's
/// LaunchAgents folder. Writing the file is the whole switch; launchd reads it at the next login,
/// so nothing is started or stopped behind the user's back in this session.
struct LoginItem {
    static let label = "com.cuetap.agent"
    let executable: URL

    var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    var isEnabled: Bool { FileManager.default.fileExists(atPath: url.path) }

    func setEnabled(_ enabled: Bool) throws {
        enabled ? try enable() : try disable()
    }

    private func enable() throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let agent: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [executable.path, "serve"],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func disable() throws {
        guard isEnabled else { return }
        try FileManager.default.removeItem(at: url)
    }
}
