import Foundation

struct DemoHotkey: Equatable {
    let keyCode: UInt16
    let modifiers: KeyModifiers
    let label: String
    static let `default` = try! DemoHotkey("cmd+shift+r")

    init(_ value: String) throws {
        let parts = value.lowercased().split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        guard let key = parts.last, key.count == 1,
              key.unicodeScalars.allSatisfy({ (97...122).contains($0.value) || (48...57).contains($0.value) }),
              let stroke = USKeyboardLayout.stroke(for: Character(key)) else {
            throw ControlError("invalid_hotkey", "Use a hotkey such as cmd+shift+r. The main key must be a-z or 0-9.")
        }
        var flags: KeyModifiers = []
        for name in parts.dropLast() {
            let flag: KeyModifiers
            switch name {
            case "cmd", "command": flag = .command
            case "ctrl", "control": flag = .control
            case "alt", "option": flag = .option
            case "shift": flag = .shift
            default: throw ControlError("invalid_hotkey", "Unknown modifier: \(name).")
            }
            guard !flags.contains(flag) else { throw ControlError("invalid_hotkey", "Hotkey modifiers must not repeat.") }
            flags.insert(flag)
        }
        guard flags.rawValue.nonzeroBitCount >= 2, !flags.intersection([.command, .control]).isEmpty else {
            throw ControlError("invalid_hotkey", "Use at least two modifiers, including cmd or ctrl.")
        }
        guard !(key == "q" && flags.contains(.command) && (flags.contains(.shift) || flags.contains(.control))) else {
            throw ControlError("invalid_hotkey", "This shortcut is reserved for logout or screen locking. Choose another hotkey.")
        }
        keyCode = stroke.keyCode
        modifiers = flags
        let names: [(KeyModifiers, String)] = [(.command,"cmd"),(.control,"ctrl"),(.option,"option"),(.shift,"shift")]
        label = (names.filter { flags.contains($0.0) }.map { $0.1 } + [key]).joined(separator: "+")
    }
}
