import Foundation

struct ControlError: Error, Codable, CustomStringConvertible {
    let code: String
    let message: String
    var description: String { message }
    init(_ code: String, _ message: String) { self.code = code; self.message = message }
}

struct ControlRequest: Codable {
    var protocolVersion = 1
    let command: String
    var value: String?
    var configuration: ConfigurationCommand?
}

struct PermissionStatus: Codable {
    let listen: Bool
    let post: Bool
    let secureInput: Bool
    let englishInputSource: Bool
    var ready: Bool { listen && post && !secureInput && englishInputSource }
}

struct RuntimeStatus: Codable {
    var running: Bool
    var pid: Int32?
    var executable: String?
    var state: String = "off"
    var phase: String = "off"
    var ready: Bool = false
    var configurationName: String?
    var configurationPath: String?
    var configurationID: String?
    var configurationDescription: String?
    var actionCount: Int = 0
    var position: Int = 0
    var hotkey: String
    var permissions: PermissionStatus?
    var advanceShortcut: String = SegmentAdvanceShortcut.default.label
    var segmentCount: Int = 0
    var segmentIndex: Int = 0 // One-based in the public protocol; zero means no loaded script.
    var segmentName: String?
    var segmentPosition: Int = 0
    var segmentActionCount: Int = 0
}

struct ControlResponse: Codable {
    static let version = "0.4.0"
    var ok = true
    var version = Self.version
    var protocolVersion = 1
    var message: String
    var status: RuntimeStatus?
    var error: ControlError?
    var configurations: [ConfigurationInfo]?
    var outputPath: String?
    var diagnostics: DoctorReport?

    static func failure(_ error: Error) -> Self {
        let detail = (error as? ControlError) ?? ControlError(error is ScriptError ? "invalid_script" : "operation_failed", String(describing: error))
        return Self(ok: false, message: detail.message, error: detail)
    }
}
