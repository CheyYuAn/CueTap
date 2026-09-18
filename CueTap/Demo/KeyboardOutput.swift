import CoreGraphics

/// Translate demo actions into balanced US-English key events. The session owns
/// interception; this object owns only the modifier state delivered to the app.
final class KeyboardOutput {
    private enum OutputError: Error { case unsupportedCharacter, allocationFailed }
    static let eventMarker: Int64 = 0x435545544150
    private let source = CGEventSource(stateID: .privateState)!
    private var deliveredFlags: CGEventFlags = []

    func notePassedFlags(_ flags: CGEventFlags) {
        deliveredFlags = flags
    }

    private func post(_ event: CGEvent, proxy: CGEventTapProxy?) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        if let proxy { event.tapPostEvent(proxy) }
        else { event.post(tap: .cgSessionEventTap) }
    }

    func synchronizeModifiers(_ flags: CGEventFlags, proxy: CGEventTapProxy?) {
        let keys: [(CGEventFlags, CGKeyCode)] = [(.maskCommand, 55), (.maskShift, 56),
            (.maskAlternate, 58), (.maskControl, 59), (.maskSecondaryFn, 63), (.maskAlphaShift, 57)]
        for (flag, key) in keys where deliveredFlags.contains(flag) != flags.contains(flag) {
            if flags.contains(flag) { deliveredFlags.insert(flag) }
            else { deliveredFlags.remove(flag) }
            if let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
                event.type = .flagsChanged
                event.flags = deliveredFlags
                post(event, proxy: proxy)
            }
        }
        deliveredFlags = flags
    }

    func emit(_ action: DemoAction, proxy: CGEventTapProxy?) throws {
        let key: CGKeyCode
        let flags: CGEventFlags
        switch action {
        case .left: (key, flags) = (123, [])
        case .right: (key, flags) = (124, [])
        case .enter: (key, flags) = (36, [])
        case .tab: (key, flags) = (48, [])
        case .character(let character):
            guard let stroke = USKeyboardLayout.stroke(for: character) else {
                throw OutputError.unsupportedCharacter
            }
            (key, flags) = (stroke.keyCode, stroke.shifted ? .maskShift : [])
        }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else {
            throw OutputError.allocationFailed
        }
        synchronizeModifiers(flags, proxy: proxy)
        down.flags = flags
        up.flags = flags
        post(down, proxy: proxy)
        post(up, proxy: proxy)
        synchronizeModifiers([], proxy: proxy)
    }

}
