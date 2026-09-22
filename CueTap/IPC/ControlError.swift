import Foundation

struct ControlError: Error, Codable, CustomStringConvertible {
    let code: String
    let message: String
    var description: String { message }
    init(_ code: String, _ message: String) { self.code = code; self.message = message }
}
