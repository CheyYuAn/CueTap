import Foundation

struct ControlRequest: Codable {
    var protocolVersion = 1
    let command: String
    var value: String?
    var configuration: ConfigurationCommand?
}
