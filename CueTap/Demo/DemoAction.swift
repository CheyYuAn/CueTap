import Foundation

enum DemoAction: Equatable {
    case character(Character)
    case left, right, enter, tab, backspace
}

struct ScriptError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

/// Expand configuration before playback. Playback has no file I/O.
struct DemoSegment: Equatable {
    let name: String
    var description: String = ""
    let actions: [DemoAction]
}
