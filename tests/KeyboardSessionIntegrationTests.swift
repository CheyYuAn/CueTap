import Carbon
import CoreGraphics
import Foundation
import XCTest

final class KeyboardSessionIntegrationTests: XCTestCase {
    private static let inputMarker: Int64 = 0x43554554455354
    private var events: [(CGEventType, CGKeyCode, Int64)] = []

    /// Run the real CLI, exercise its event tap, and consume test traffic in a
    /// downstream tap. No input reaches the user's editor during this test.
    func testRunningCLIInterceptsHotkeyAdvancesAndRestoresNormalInput() throws {
        try exercise(scriptURL: ExampleFixture.url, expectedKeys:
                     [43, 2, 34, 9, 47, 43, 44, 2, 34, 9, 47]
                     + Array(repeating: 123, count: 7)
                     + [49, 8, 37, 0, 1, 1, 41, 39, 11, 31, 2, 16, 39]
                     + [124, 36, 4, 14, 37, 37, 31])
    }

    func testCustomJSONActuallyChangesNativePlayback() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("CueTap custom \(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data(#"{"version":1,"name":"Custom","actions":[{"type":"text","value":"Z9{}"},{"type":"key","key":"tab"},{"type":"key","key":"left","count":2},{"type":"key","key":"enter"}]}"#.utf8).write(to: file)
        try exercise(scriptURL: file, expectedKeys: [6, 25, 33, 30, 48, 123, 123, 36])
    }

    func testChineseInputSourceRestoresOnToggleAndTermination() throws {
        let access = SystemInputSourceAccess()
        let original = try access.currentID()
        defer { try? access.select(original) }
        let filter = [kTISPropertyInputSourceID as String: "com.apple.inputmethod.SCIM.ITABC"] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              !sources.isEmpty else { throw XCTSkip("未启用系统简体拼音，无法执行中文输入源恢复验收。") }
        try access.select("com.apple.inputmethod.SCIM.ITABC")
        try exercise(scriptURL: ExampleFixture.url, expectedKeys:
                     [43, 2, 34, 9, 47, 43, 44, 2, 34, 9, 47]
                     + Array(repeating: 123, count: 7)
                     + [49, 8, 37, 0, 1, 1, 41, 39, 11, 31, 2, 16, 39]
                     + [124, 36, 4, 14, 37, 37, 31], terminateWhileActive: true)
        XCTAssertEqual(try access.currentID(), "com.apple.inputmethod.SCIM.ITABC")
    }

    private func exercise(scriptURL: URL, expectedKeys: [CGKeyCode], terminateWhileActive: Bool = false) throws {
        let inputSource = SystemInputSourceAccess()
        let originalInputSource = try inputSource.currentID()
        let englishInputSource = try inputSource.englishID()
        defer { try? inputSource.select(originalInputSource) }
        guard CGPreflightListenEventAccess(), CGPreflightPostEventAccess() else {
            throw XCTSkip("测试宿主没有原生事件权限；可从已授权终端直接运行 xctest。")
        }
        let callback: CGEventTapCallBack = { _, type, event, context in
            let marker = event.getIntegerValueField(.eventSourceUserData)
            guard marker == KeyboardSessionIntegrationTests.inputMarker || marker == KeyboardSession.eventMarker,
                  let context else { return Unmanaged.passUnretained(event) }
            let test = Unmanaged<KeyboardSessionIntegrationTests>.fromOpaque(context).takeUnretainedValue()
            test.events.append((type, CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)), marker))
            return nil
        }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let sink = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask, callback: callback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()),
              let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, sink, 0) else {
            throw XCTSkip("无法建立隔离验收输入的监听器。")
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
        CGEvent.tapEnable(tap: sink, enable: true)
        defer {
            CFMachPortInvalidate(sink)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), loopSource, .commonModes)
        }

        let process = Process()
        process.executableURL = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("cuetap")
        process.arguments = ["--script", scriptURL.path]
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        defer {
            if process.isRunning { process.terminate() }
            _ = pump(until: { !process.isRunning })
        }
        func hasTap() -> Bool {
            var count: UInt32 = 0
            guard CGGetEventTapList(0, nil, &count) == .success else { return false }
            var taps = Array(repeating: CGEventTapInformation(), count: Int(count))
            guard CGGetEventTapList(count, &taps, &count) == .success else { return false }
            return taps.prefix(Int(count)).contains { $0.tappingProcess == process.processIdentifier && $0.enabled }
        }
        guard pump(until: { hasTap() || !process.isRunning }), process.isRunning, hasTap() else {
            if process.isRunning { process.terminate(); process.waitUntilExit() }
            XCTFail("CLI 未成功建立拦截：\(String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))")
            return
        }

        let source = try XCTUnwrap(CGEventSource(stateID: .privateState))
        func post(_ type: CGEventType, _ key: CGKeyCode, flags: CGEventFlags = [], repeated: Bool = false) throws {
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: type == .keyDown))
            event.type = type
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: Self.inputMarker)
            event.setIntegerValueField(.keyboardEventAutorepeat, value: repeated ? 1 : 0)
            event.post(tap: .cgSessionEventTap)
        }
        func tapKey(_ key: CGKeyCode) throws { try post(.keyDown, key); try post(.keyUp, key) }
        func toggle() throws {
            try post(.flagsChanged, 55, flags: .maskCommand)
            try post(.flagsChanged, 56, flags: [.maskCommand, .maskShift])
            try post(.keyDown, 15, flags: [.maskCommand, .maskShift])
            try post(.keyUp, 15, flags: [.maskCommand, .maskShift])
            try post(.flagsChanged, 56, flags: .maskCommand)
            try post(.flagsChanged, 55)
        }
        func outputKeys() -> [CGKeyCode] {
            events.filter { $0.0 == .keyDown && $0.2 == KeyboardSession.eventMarker }.map { $0.1 }
        }
        func physicalKeys() -> [CGKeyCode] {
            events.filter { $0.0 == .keyDown && $0.2 == Self.inputMarker }.map { $0.1 }
        }

        try tapKey(14) // off: ordinary E reaches the sink
        XCTAssertTrue(pump(until: { physicalKeys() == [14] }))
        try toggle()
        try post(.keyDown, 0)
        try post(.keyDown, 0, repeated: true)
        try post(.keyUp, 0)
        XCTAssertTrue(pump(until: { outputKeys().count == 1 }))
        XCTAssertEqual(try inputSource.currentID(), englishInputSource)
        XCTAssertEqual(outputKeys(), [expectedKeys[0]])
        XCTAssertEqual(physicalKeys(), [14])

        // Early close, ordinary input, then restart from the first action.
        try toggle()
        try tapKey(11)
        XCTAssertTrue(pump(until: { physicalKeys().count == 2 }))
        XCTAssertEqual(physicalKeys(), [14, 11])
        XCTAssertEqual(try inputSource.currentID(), originalInputSource)
        try toggle()
        for index in 0..<expectedKeys.count { try tapKey(CGKeyCode(index % 10)) }
        XCTAssertTrue(pump(until: { outputKeys().count == expectedKeys.count + 1 }))
        XCTAssertEqual(Array(outputKeys().dropFirst()), expectedKeys)
        XCTAssertEqual(try inputSource.currentID(), englishInputSource)
        try tapKey(49) // completed: swallowed
        try tapKey(36)
        try toggle()
        try tapKey(2) // off again: D reaches the sink
        XCTAssertTrue(pump(until: { physicalKeys().count == 3 }))
        XCTAssertEqual(physicalKeys(), [14, 11, 2])
        XCTAssertEqual(outputKeys().count, expectedKeys.count + 1)
        XCTAssertFalse(physicalKeys().contains(15)) // R hotkey never leaked
        XCTAssertEqual(try inputSource.currentID(), originalInputSource)
        if terminateWhileActive {
            try toggle()
            try tapKey(0)
            XCTAssertTrue(pump(until: { outputKeys().count == expectedKeys.count + 2 }))
            XCTAssertEqual(try inputSource.currentID(), englishInputSource)
        }
        process.terminate()
        XCTAssertTrue(pump(until: { !process.isRunning }))
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(try inputSource.currentID(), originalInputSource)
    }

    private func pump(until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(4)
        while !condition() && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }
}
