import Foundation

/// All calls belong to the event tap's main run loop; no asynchronous playback queue.
final class DemoController {
    enum State: Equatable { case off, arming, playing, waiting, complete }
    static let toggleKey: UInt16 = 15 // R on the Mac keyboard
    private(set) var state: State = .off
    private(set) var position = 0
    private(set) var targetPID: Int32?
    private var segments: [DemoSegment]
    private(set) var segmentIndex = 0
    private(set) var segmentPosition = 0
    var segmentCount: Int { segments.count }
    var segmentName: String { segments[segmentIndex].name }
    var segmentActionCount: Int { segments[segmentIndex].actions.count }
    private var waitingForPointerRelease = false
    private var hotkey: DemoHotkey
    private var downKeys: Set<UInt16> = []
    private var suppressedKeys: Set<UInt16> = []
    private var waitingForHotkeyRelease = false

    init(actions: [DemoAction], hotkey: DemoHotkey = .default) {
        self.segments = [DemoSegment(name: "Demo", actions: actions)]
        self.hotkey = hotkey
    }

    init(segments: [DemoSegment], hotkey: DemoHotkey = .default) {
        precondition(!segments.isEmpty)
        self.segments = segments
        self.hotkey = hotkey
    }

    func frontmostChanged(_ pid: Int32?) {
        if state != .off && state != .waiting && targetPID != pid { cancel() }
    }

    /// The adapter calls this only after a complete, non-dragging advance click.
    func advanceSegment(frontmostPID: Int32?, modifiers: KeyModifiers) {
        guard state == .waiting, let frontmostPID, segmentIndex + 1 < segments.count else { return }
        segmentIndex += 1
        segmentPosition = 0
        targetPID = frontmostPID
        state = .arming
        waitingForPointerRelease = true
        releasePointerGate(modifiers)
    }

    private func releasePointerGate(_ modifiers: KeyModifiers) {
        if waitingForPointerRelease && modifiers.isEmpty && downKeys.isEmpty {
            waitingForPointerRelease = false
            state = .playing
        }
    }

    var canReconfigure: Bool {
        state == .off && !waitingForHotkeyRelease && downKeys.isEmpty && suppressedKeys.isEmpty
    }

    func configure(actions: [DemoAction], hotkey: DemoHotkey) throws {
        guard canReconfigure else { throw ControlError("busy", "Turn the demo off and release all keys before changing configuration or hotkey.") }
        try configure(segments: [DemoSegment(name: "Demo", actions: actions)], hotkey: hotkey)
    }

    func configure(segments: [DemoSegment], hotkey: DemoHotkey) throws {
        guard canReconfigure else { throw ControlError("busy", "Stop the demo and release all keys before changing configuration.") }
        precondition(!segments.isEmpty)
        self.segments = segments
        self.hotkey = hotkey
        position = 0
        segmentIndex = 0
        segmentPosition = 0
    }

    func cancel() {
        state = .off
        position = 0
        targetPID = nil
        waitingForHotkeyRelease = false
        waitingForPointerRelease = false
        segmentIndex = 0
        segmentPosition = 0
        // Retain suppressed keys until their physical key-up, even after cancellation.
    }

    func handle(_ input: KeyboardInput, frontmostPID: Int32?) -> InputDecision {
        guard !input.isSynthetic else { return InputDecision() }
        frontmostChanged(frontmostPID)

        let wasDown = downKeys.contains(input.keyCode)
        switch input.kind {
        case .down: downKeys.insert(input.keyCode)
        case .up: downKeys.remove(input.keyCode)
        case .modifiers: break
        }

        if input.kind == .down,
           input.keyCode == hotkey.keyCode,
           input.modifiers == hotkey.modifiers,
           !input.isRepeat, !wasDown, !waitingForHotkeyRelease {
            suppressedKeys.insert(input.keyCode)
            waitingForHotkeyRelease = true
            if state == .off, let frontmostPID {
                position = 0
                segmentIndex = 0
                segmentPosition = 0
                waitingForPointerRelease = false
                targetPID = frontmostPID
                state = .arming
            } else {
                cancel()
                waitingForHotkeyRelease = true
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
                result.action = segments[segmentIndex].actions[segmentPosition]
                position += 1
                segmentPosition += 1
                if segmentPosition == segmentActionCount {
                    state = segmentIndex + 1 < segments.count ? .waiting : .complete
                }
            }
        }

        if gating, downKeys.isEmpty, input.modifiers.isEmpty {
            waitingForHotkeyRelease = false
            if state == .arming { state = segments[segmentIndex].actions.isEmpty ? .complete : .playing }
        }
        releasePointerGate(input.modifiers)
        return result
    }
}
