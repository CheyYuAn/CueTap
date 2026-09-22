import Foundation

struct ControlResponse: Codable {
    static let version = "0.5.0"
    var ok = true
    var version = Self.version
    var protocolVersion = 1
    var message: String
    var status: RuntimeStatus?
    var error: ControlError?
    var configurations: [ConfigurationInfo]?
    var outputPath: String?
    var diagnostics: DoctorReport?
    var compile: CompileReport?
    var comparison: TextComparison?
    var comparisons: [FileComparison]?
    var profiles: [ProfileInfo]?

    static func failure(_ error: Error) -> Self {
        let detail = (error as? ControlError) ?? ControlError(error is ScriptError ? "invalid_script" : "operation_failed", String(describing: error))
        return Self(ok: false, message: detail.message, error: detail)
    }
}
