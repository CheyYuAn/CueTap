import Foundation

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
