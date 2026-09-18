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
    private var physicalFlags: CGEventFlags = []
    private(set) var failure: String?

    init(actions: [DemoAction], inputSource: DemoInputSource = DemoInputSource()) {
        self.inputSource = inputSource
        controller = DemoController(actions: actions)
    }

    static func checkPermissions() throws {
        guard CGPreflightListenEventAccess(), CGPreflightPostEventAccess() else {
            throw SessionError.unavailable("缺少输入监听或辅助功能权限。请在系统设置 → 隐私与安全性中为启动终端或 cuetap 授权，然后重新启动。程序不会自行修改权限。")
        }
        guard !IsSecureEventInputEnabled() else {
            throw SessionError.unavailable("当前启用了安全输入，无法监听键盘。请结束安全输入后重新启动。")
        }
    }

    func run() throws {
        try Self.checkPermissions()
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged]
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
            throw SessionError.unavailable("无法建立键盘拦截。请检查辅助功能与输入监听权限后重新启动。")
        }
        self.tap = tap
        guard let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw SessionError.unavailable("无法建立键盘事件循环。")
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
                self.stop(reason: "键盘监听已失效，CueTap 已退出。请检查权限或安全输入状态后重新启动。")
                return
            }
            self.checkFrontmostApplication()
            guard self.failure == nil else { return }
            do { try self.inputSource.synchronize(active: self.controller.state != .off) }
            catch { self.stop(reason: "输入源控制失败，CueTap 已退出：\(error)") }
        }
        RunLoop.main.add(watchdog!, forMode: .common)
        for number in [SIGINT, SIGTERM, SIGHUP] {
            signal(number, SIG_IGN)
            let signalSource = DispatchSource.makeSignalSource(signal: number, queue: .main)
            signalSource.setEventHandler { [weak self] in self?.stop() }
            signalSource.resume()
            signalSources.append(signalSource)
        }
        defer { cleanUp() }
        CFRunLoopRun()
    }

    func receive(proxy: CGEventTapProxy?, type: CGEventType, event: CGEvent)
        -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stop(reason: "系统停用了键盘监听，CueTap 已退出，不会自动继续演示。")
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.eventMarker {
            return Unmanaged.passUnretained(event)
        }
        let kind: KeyboardInput.Kind
        switch type {
        case .keyDown: kind = .down
        case .keyUp: kind = .up
        case .flagsChanged: kind = .modifiers
        default: return Unmanaged.passUnretained(event)
        }
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
            stop(reason: "输入源控制失败，CueTap 已退出：\(error)")
            return result.suppress ? nil : Unmanaged.passUnretained(event)
        }
        if let action = result.action {
            do { try output.emit(action, proxy: proxy) }
            catch { stop(reason: "模拟按键失败，CueTap 已退出。") }
        }
        if !result.suppress { output.notePassedFlags(event.flags) }
        return result.suppress ? nil : Unmanaged.passUnretained(event)
    }

    private func checkFrontmostApplication(proxy: CGEventTapProxy? = nil) {
        guard let target = controller.targetPID,
              NSWorkspace.shared.frontmostApplication?.processIdentifier != target else { return }
        controller.cancel()
        output.synchronizeModifiers(physicalFlags, proxy: proxy)
        do { try inputSource.restore() }
        catch { stop(reason: "\(error)") }
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

    private func stop(reason: String? = nil) {
        if let reason { failure = reason }
        controller.cancel()
        do { try inputSource.restore() }
        catch { failure = [failure, String(describing: error)].compactMap { $0 }.joined(separator: "\n") }
        output.synchronizeModifiers(CGEventSource.flagsState(.hidSystemState), proxy: nil)
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        CFRunLoopStop(CFRunLoopGetMain())
    }

    private func cleanUp() {
        do { try inputSource.restore() }
        catch { failure = [failure, String(describing: error)].compactMap { $0 }.joined(separator: "\n") }
        watchdog?.invalidate()
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        signalSources.forEach { $0.cancel() }
        if let tap { CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
    }
}
