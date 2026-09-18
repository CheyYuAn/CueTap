import AppKit
import CoreGraphics
import XCTest

final class KeyboardOutputTests: XCTestCase {
    private struct Stroke {
        var type: CGEventType
        var key: CGKeyCode
        var flags: CGEventFlags
    }

    private var strokes: [Stroke] = []
    private var completed: XCTestExpectation?
    private var expectedCount = 0

    /// Observe and consume only CueTap-marked output, before it reaches any app.
    /// This checks actual Quartz events without typing into a user's document.
    func testQuartzOutputSequenceModifiersAndBalancedReleases() throws {
        guard CGPreflightListenEventAccess(), CGPreflightPostEventAccess() else {
            throw XCTSkip("当前测试进程没有原生事件权限。")
        }
        guard NSWorkspace.shared.frontmostApplication != nil else {
            throw XCTSkip("需要已登录的图形会话。")
        }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard event.getIntegerValueField(.eventSourceUserData) == KeyboardSession.eventMarker,
                  let context else { return Unmanaged.passUnretained(event) }
            let test = Unmanaged<KeyboardOutputTests>.fromOpaque(context).takeUnretainedValue()
            test.strokes.append(Stroke(type: type,
                                       key: CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)),
                                       flags: event.flags))
            if test.strokes.count == test.expectedCount { test.completed?.fulfill() }
            return nil
        }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap,
                                         options: .defaultTap, eventsOfInterest: mask,
                                         callback: callback,
                                         userInfo: Unmanaged.passUnretained(self).toOpaque()),
              let loopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            throw XCTSkip("当前测试进程无法建立输出验收事件监听。")
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), loopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        defer {
            CFMachPortInvalidate(tap)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), loopSource, .commonModes)
        }

        let actions = try ExampleFixture.load().actions
        let session = KeyboardSession(actions: actions)
        let inputSource = try XCTUnwrap(CGEventSource(stateID: .privateState))
        func input(_ type: CGEventType, key: CGKeyCode, flags: CGEventFlags = []) throws {
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: inputSource,
                                            virtualKey: key, keyDown: type == .keyDown))
            event.type = type
            event.flags = flags
            XCTAssertNil(session.receive(proxy: nil, type: type, event: event))
        }

        // Seven shifted characters each add a Shift press and release to 38 key pairs.
        expectedCount = 90
        completed = expectation(description: "38 个动作对应的 Quartz 事件已到达并被测试监听器消费")
        try input(.keyDown, key: 15, flags: [.maskCommand, .maskShift])
        try input(.keyUp, key: 15)
        for _ in actions {
            try input(.keyDown, key: 0)
            try input(.keyUp, key: 0)
        }
        waitForExpectations(timeout: 5)

        let downs = strokes.filter { $0.type == .keyDown }
        let ups = strokes.filter { $0.type == .keyUp }
        XCTAssertEqual(downs.count, 38)
        XCTAssertEqual(ups.count, 38)
        // Explicit expected US keycodes, independent of the implementation's mapping.
        XCTAssertEqual(downs.map(\.key),
                       [43, 2, 34, 9, 47, 43, 44, 2, 34, 9, 47]
                       + Array(repeating: 123, count: 7)
                       + [49, 8, 37, 0, 1, 1, 41, 39, 11, 31, 2, 16, 39]
                       + [124, 36, 4, 14, 37, 37, 31])
        XCTAssertEqual(ups.map(\.key), downs.map(\.key))
        XCTAssertEqual(ups.map(\.flags), downs.map(\.flags))
        XCTAssertEqual(downs.filter { $0.flags.contains(.maskShift) }.count, 7)
        XCTAssertTrue(downs.allSatisfy { !$0.flags.contains(.maskCommand) && !$0.flags.contains(.maskControl) })

        var pressedKeys: Set<CGKeyCode> = []
        var shift = false
        for stroke in strokes {
            if stroke.type == .flagsChanged {
                XCTAssertEqual(stroke.key, 56)
                shift = stroke.flags.contains(.maskShift)
            } else if stroke.type == .keyDown {
                XCTAssertTrue(pressedKeys.insert(stroke.key).inserted)
                XCTAssertEqual(stroke.flags.contains(.maskShift), shift)
            } else if stroke.type == .keyUp {
                XCTAssertNotNil(pressedKeys.remove(stroke.key))
            }
        }
        XCTAssertTrue(pressedKeys.isEmpty)
        XCTAssertFalse(shift)
    }
}
