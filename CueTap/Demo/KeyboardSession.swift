import AppKit
import Carbon
import CoreGraphics
import Foundation

enum SessionError: Error, CustomStringConvertible {
    case unavailable(String)
    var description: String {
        switch self { case .unavailable(let message): return message }
    }
}

/// Quartz adapter. Synthetic events use private state and a marker; physical input
/// remains separate from the flags delivered to the frontmost application.
final class KeyboardSession {
    static let eventMarker = KeyboardOutput.eventMarker
    private let controller: DemoController
    private let output = KeyboardOutput()
    private let inputSource: DemoInputSource
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var observer: NSObjectProtocol?
    private var watchdog: Timer?
    private var signalSources: [DispatchSourceSignal] = []
    private var advanceGesture = SegmentAdvanceGesture()
    private var leftButtonDown = false
    private var normalizeLeftRelease = false
    private var physicalFlags: CGEventFlags = []
    private(set) var failure: String?
    var onChange: (() -> Void)?
    var onStop: (() -> Void)?
    var state: DemoController.State { controller.state }
    var position: Int { controller.position }
    var canReconfigure: Bool { controller.canReconfigure && !leftButtonDown && Self.modifiers(physicalFlags).isEmpty }
    var segmentIndex: Int { controller.segmentIndex }
    var segmentPosition: Int { controller.segmentPosition }
    var segmentActionCount: Int { controller.segmentActionCount }
    var segmentName: String { controller.segmentName }

    init(actions: [DemoAction], hotkey: DemoHotkey = .default, inputSource: DemoInputSource = DemoInputSource()) {
        self.inputSource = inputSource
        controller = DemoController(actions: actions, hotkey: hotkey)
    }

    init(segments: [DemoSegment], hotkey: DemoHotkey = .default,
         advanceShortcut: SegmentAdvanceShortcut = .default, inputSource: DemoInputSource = DemoInputSource()) {
        self.inputSource = inputSource
        controller = DemoController(segments: segments, hotkey: hotkey)
        advanceGesture.shortcut = advanceShortcut
    }

    static func checkPermissions() throws {
        guard CGPreflightListenEventAccess(), CGPreflightPostEventAccess() else {
            throw SessionError.unavailable("Input Monitoring or Accessibility permission is missing. Authorize your terminal or cuetap in System Settings > Privacy & Security, then restart.")
        }
        guard !IsSecureEventInputEnabled() else {
            throw SessionError.unavailable("Secure Input is enabled. Disable the secure input session before restarting.")
        }
    }

    func run() throws {
        try start()
        defer { cleanUp() }
        CFRunLoopRun()
    }

    func start() throws {
        try Self.checkPermissions()
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { proxy, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let session = Unmanaged<KeyboardSession>.fromOpaque(context).takeUnretainedValue()
            return session.receive(proxy: proxy, type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .defaultTap, eventsOfInterest: mask,
                                         callback: callback,
                                         userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw SessionError.unavailable("Cannot install the keyboard event tap. Check Accessibility and Input Monitoring permissions.")
        }
        self.tap = tap
        guard let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw SessionError.unavailable("Cannot create the keyboard run-loop source.")
        }
        runLoopSource = loopSource
        physicalFlags = CGEventSource.flagsState(.hidSystemState)
        output.notePassedFlags(physicalFlags)
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.checkFrontmostApplication() }
        watchdog = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let tap = self.tap else { return }
            if !CGEvent.tapIsEnabled(tap: tap) || IsSecureEventInputEnabled() {
                self.stop(reason: "Keyboard monitoring stopped. CueTap has exited. Check permissions and Secure Input before restarting.")
                return
            }
            self.checkFrontmostApplication()
            guard self.failure == nil else { return }
            do { try self.inputSource.synchronize(active: self.controller.state != .off) }
            catch { self.stop(reason: "Input-source control failed. CueTap has stopped: \(error)") }
        }
        RunLoop.main.add(watchdog!, forMode: .common)
        for number in [SIGINT, SIGTERM, SIGHUP] {
            signal(number, SIG_IGN)
            let signalSource = DispatchSource.makeSignalSource(signal: number, queue: .main)
            signalSource.setEventHandler { [weak self] in self?.stop() }
            signalSource.resume()
            signalSources.append(signalSource)
        }
    }

    func configure(actions: [DemoAction], hotkey: DemoHotkey) throws {
        try controller.configure(actions: actions, hotkey: hotkey)
        onChange?()
    }

    func configure(segments: [DemoSegment], hotkey: DemoHotkey, advanceShortcut: SegmentAdvanceShortcut) throws {
        guard canReconfigure else { throw ControlError("busy", "Stop the demo and release all keys and mouse buttons.") }
        try controller.configure(segments: segments, hotkey: hotkey)
        advanceGesture = SegmentAdvanceGesture(shortcut: advanceShortcut)
        onChange?()
    }

    func stopDemo() throws {
        controller.cancel()
        advanceGesture.reset()
        output.synchronizeModifiers(CGEventSource.flagsState(.hidSystemState), proxy: nil)
        do { try inputSource.restore() }
        catch { stop(reason: String(describing: error)); throw error }
        onChange?()
    }

    func receive(proxy: CGEventTapProxy?, type: CGEventType, event: CGEvent)
        -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stop(reason: "The system disabled the keyboard tap. CueTap has stopped and will not resume automatically.")
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.eventMarker {
            return Unmanaged.passUnretained(event)
        }
        if [.leftMouseDown, .leftMouseUp, .leftMouseDragged].contains(type) {
            return receivePointer(proxy: proxy, type: type, event: event)
        }
        let kind: KeyboardInput.Kind
        switch type {
        case .keyDown: kind = .down
        case .keyUp: kind = .up
        case .flagsChanged: kind = .modifiers
        default: return Unmanaged.passUnretained(event)
        }
        let previousState = controller.state
        let previousReconfigure = canReconfigure
        defer { if previousState != controller.state || previousReconfigure != canReconfigure { onChange?() } }
        physicalFlags = event.flags
        checkFrontmostApplication(proxy: proxy)
        guard failure == nil else { return Unmanaged.passUnretained(event) }
        let input = KeyboardInput(kind: kind,
                                  keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                                  modifiers: Self.modifiers(event.flags),
                                  isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        let result = controller.handle(input, frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        if result.neutralizeModifiers { output.synchronizeModifiers([], proxy: proxy) }
        do { try inputSource.synchronize(active: controller.state != .off) }
        catch {
            stop(reason: "Input-source control failed. CueTap has stopped: \(error)")
            return result.suppress ? nil : Unmanaged.passUnretained(event)
        }
        if let action = result.action {
            do { try output.emit(action, proxy: proxy) }
            catch { stop(reason: "Failed to send a keyboard event. CueTap has exited.") }
        }
        if !result.suppress { output.notePassedFlags(event.flags) }
        return result.suppress ? nil : Unmanaged.passUnretained(event)
    }

    private func receivePointer(proxy: CGEventTapProxy?, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let previousReconfigure = canReconfigure
        defer { if previousReconfigure != canReconfigure { onChange?() } }
        physicalFlags = event.flags
        checkFrontmostApplication(proxy: proxy)
        let kind: SegmentAdvanceGesture.Event = type == .leftMouseDown ? .down : type == .leftMouseUp ? .up : .dragged
        if type == .leftMouseDown { leftButtonDown = true }
        if type == .leftMouseUp { leftButtonDown = false }
        let active = controller.state != .off
        if type == .leftMouseDown { normalizeLeftRelease = active }
        let shouldNormalize = active || normalizeLeftRelease
        let advance = advanceGesture.handle(kind, waiting: controller.state == .waiting,
                                            modifiers: Self.modifiers(physicalFlags),
                                            clickCount: Int(event.getIntegerValueField(.mouseEventClickState)))
        if shouldNormalize {
            // The editor must receive an ordinary positioning click, not Cmd-click navigation.
            output.synchronizeModifiers([], proxy: proxy)
            event.flags = []
        }
        if type == .leftMouseUp {
            normalizeLeftRelease = false
            if advance {
                controller.advanceSegment(frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                                          modifiers: Self.modifiers(physicalFlags))
                onChange?()
            }
            if !active { output.synchronizeModifiers(physicalFlags, proxy: proxy) }
        }
        return Unmanaged.passUnretained(event)
    }

    private func checkFrontmostApplication(proxy: CGEventTapProxy? = nil) {
        let previous = controller.state
        controller.frontmostChanged(NSWorkspace.shared.frontmostApplication?.processIdentifier)
        guard previous != .off, controller.state == .off else { return }
        advanceGesture.reset()
        output.synchronizeModifiers(physicalFlags, proxy: proxy)
        do { try inputSource.restore() }
        catch { stop(reason: "\(error)") }
        onChange?()
    }

    private static func modifiers(_ flags: CGEventFlags) -> KeyModifiers {
        var result: KeyModifiers = []
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskSecondaryFn) { result.insert(.function) }
        return result
    }

    func stop(reason: String? = nil) {
        if let reason { failure = reason }
        controller.cancel()
        do { try inputSource.restore() }
        catch { failure = [failure, String(describing: error)].compactMap { $0 }.joined(separator: "\n") }
        output.synchronizeModifiers(CGEventSource.flagsState(.hidSystemState), proxy: nil)
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        cleanUp()
        onChange?()
        if let onStop { onStop() } else { CFRunLoopStop(CFRunLoopGetMain()) }
    }

    private func cleanUp() {
        do { try inputSource.restore() }
        catch { failure = [failure, String(describing: error)].compactMap { $0 }.joined(separator: "\n") }
        watchdog?.invalidate()
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        signalSources.forEach { $0.cancel() }
        if let tap { CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        observer = nil
        watchdog = nil
        signalSources.removeAll()
    }
}
