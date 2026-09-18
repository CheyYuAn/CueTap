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

/// All calls belong to the event tap's main run loop; no asynchronous playback queue.
final class DemoController {
    enum State: Equatable { case off, arming, playing, complete }
    static let toggleKey: UInt16 = 15 // R on the Mac keyboard
    private(set) var state: State = .off
    private(set) var position = 0
    private(set) var targetPID: Int32?
    private let actions: [DemoAction]
    private var downKeys: Set<UInt16> = []
    private var suppressedKeys: Set<UInt16> = []
    private var waitingForHotkeyRelease = false

    init(actions: [DemoAction]) {
        self.actions = actions
    }

    func cancel() {
        state = .off
        position = 0
        targetPID = nil
        waitingForHotkeyRelease = false
        // Retain suppressed keys until their physical key-up, even after cancellation.
    }

    func handle(_ input: KeyboardInput, frontmostPID: Int32?) -> InputDecision {
        guard !input.isSynthetic else { return InputDecision() }
        if state != .off && targetPID != frontmostPID { cancel() }

        let wasDown = downKeys.contains(input.keyCode)
        switch input.kind {
        case .down: downKeys.insert(input.keyCode)
        case .up: downKeys.remove(input.keyCode)
        case .modifiers: break
        }

        if input.kind == .down,
           input.keyCode == Self.toggleKey,
           input.modifiers == .hotkey,
           !input.isRepeat, !wasDown, !waitingForHotkeyRelease {
            suppressedKeys.insert(input.keyCode)
            waitingForHotkeyRelease = true
            if state == .off, let frontmostPID {
                position = 0
                targetPID = frontmostPID
                state = .arming
            } else {
                state = .off
                position = 0
                targetPID = nil
            }
            return InputDecision(suppress: true, neutralizeModifiers: true)
        }

        let gating = waitingForHotkeyRelease
        let intercepting = state != .off || gating
        var result = InputDecision(suppress: intercepting)
        switch input.kind {
        case .modifiers:
            break
        case .up:
            if suppressedKeys.remove(input.keyCode) != nil { result.suppress = true }
        case .down:
            if suppressedKeys.contains(input.keyCode) { result.suppress = true }
            if intercepting { suppressedKeys.insert(input.keyCode) }
            if state == .playing, !gating, !input.isRepeat, !wasDown {
                result.action = actions[position]
                position += 1
                if position == actions.count { state = .complete }
            }
        }

        if gating, !downKeys.contains(Self.toggleKey), input.modifiers.isEmpty {
            waitingForHotkeyRelease = false
            if state == .arming { state = actions.isEmpty ? .complete : .playing }
        }
        return result
    }
}
