import Foundation

struct ConfigurationCommand: Codable {
    enum Operation: String, Codable { case list, use, rename, export, remove }
    let operation: Operation
    var selector: String?
    var value: String?

    init(arguments: [String]) throws {
        guard let first = arguments.first, let operation = Operation(rawValue: first) else {
            throw ScriptError("Usage: cuetap config list | use ID | rename ID NAME | export ID FILE | remove ID")
        }
        let count = operation == .list ? 1 : [.rename, .export].contains(operation) ? 3 : 2
        guard arguments.count == count, arguments.dropFirst().allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ScriptError("Invalid arguments for config \(operation.rawValue). Run cuetap help.")
        }
        self.operation = operation
        selector = count >= 2 ? arguments[1] : nil
        if count == 3 {
            value = operation == .export
                ? URL(fileURLWithPath: (arguments[2] as NSString).expandingTildeInPath).standardizedFileURL.path
                : arguments[2]
        }
    }
}

struct ConfigurationInfo: Codable {
    let id: String
    let name: String
    let description: String
    let path: String
    let actionCount: Int
    let selected: Bool
    var segmentCount: Int = 1
    var error: String?
}
