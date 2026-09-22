import Foundation

struct DiagnosticFinding: Codable {
    let id: String
    let severity: String
    let message: String
    var suggestion: String?
}

struct DoctorReport: Codable {
    let executable: String
    let dataDirectory: String
    let configurationDirectory: String
    let logPath: String
    let permissionsScope: String
    let findings: [DiagnosticFinding]
}
