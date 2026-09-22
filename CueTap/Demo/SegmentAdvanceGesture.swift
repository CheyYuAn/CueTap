import Foundation

/// Recognizes intent only; Quartz delivery and playback stay in their own modules.
struct SegmentAdvanceGesture {
    enum Event { case down, dragged, up }
    var shortcut: SegmentAdvanceShortcut = .default
    private var pending = false

    mutating func reset() { pending = false }

    mutating func handle(_ event: Event, waiting: Bool, modifiers: KeyModifiers, clickCount: Int = 1) -> Bool {
        guard waiting else { pending = false; return false }
        switch event {
        case .down:
            pending = modifiers == shortcut.modifiers && clickCount == 1
        case .dragged:
            pending = false
        case .up:
            let complete = pending
            pending = false
            return complete
        }
        return false
    }
}
