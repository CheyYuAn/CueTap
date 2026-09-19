import Foundation

/// Keeps the interceptor active for a moment after the last action of the last segment, so a
/// keystroke typed a fraction too late is swallowed instead of reaching the document. The demo
/// turns itself off when the lock expires; it is the same block the demo applies between segments.
final class CompletionLock {
    static let seconds: TimeInterval = 3
    private let duration: TimeInterval
    private var timer: Timer?
    var isActive: Bool { timer != nil }

    init(duration: TimeInterval = CompletionLock.seconds) {
        self.duration = duration
    }

    /// Called on every state change: arms once the demo is complete, disarms as soon as it is not.
    func sync(completed: Bool, expire: @escaping () -> Void) {
        guard completed else { cancel(); return }
        guard timer == nil else { return }
        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
            self?.timer = nil
            expire()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
