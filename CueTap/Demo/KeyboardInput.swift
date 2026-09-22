import Foundation

struct KeyModifiers: OptionSet, Equatable {
    let rawValue: UInt8
    static let command = Self(rawValue: 1 << 0)
    static let shift = Self(rawValue: 1 << 1)
    static let option = Self(rawValue: 1 << 2)
    static let control = Self(rawValue: 1 << 3)
    static let function = Self(rawValue: 1 << 4)
    static let hotkey: Self = [.command, .shift]
}

struct KeyboardInput {
    enum Kind { case down, up, modifiers }
    var kind: Kind
    var keyCode: UInt16
    var modifiers: KeyModifiers = []
    var isRepeat = false
    var isSynthetic = false
}

struct InputDecision {
    var suppress = false
    var action: DemoAction?
    var neutralizeModifiers = false
}
