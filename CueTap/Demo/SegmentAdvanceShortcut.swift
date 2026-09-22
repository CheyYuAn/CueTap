import Foundation

/// A user preference, independent of both the toggle hotkey and script contents.
struct SegmentAdvanceShortcut: Equatable {
    let modifiers: KeyModifiers
    let label: String
    static let `default` = try! SegmentAdvanceShortcut("cmd+click")

    init(_ value: String) throws {
        let parts = value.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard parts.last == "click", parts.count > 1 else {
            throw ControlError("invalid_advance_shortcut", "Use modifiers plus click, for example cmd+click.")
        }
        var flags: KeyModifiers = []
        for name in parts.dropLast() {
            let flag: KeyModifiers
            switch name {
            case "cmd", "command": flag = .command
            case "ctrl", "control": flag = .control
            case "option", "alt": flag = .option
            case "shift": flag = .shift
            default: throw ControlError("invalid_advance_shortcut", "Unknown modifier: \(name).")
            }
            guard !flags.contains(flag) else { throw ControlError("invalid_advance_shortcut", "Modifiers must not repeat.") }
            flags.insert(flag)
        }
        modifiers = flags
        let names: [(KeyModifiers, String)] = [(.command,"cmd"),(.control,"ctrl"),(.option,"option"),(.shift,"shift")]
        label = (names.filter { flags.contains($0.0) }.map { $0.1 } + ["click"]).joined(separator: "+")
    }
}
