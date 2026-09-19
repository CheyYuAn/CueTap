import Foundation
import XCTest

final class MultiSegmentTests: XCTestCase {
    private func controller() -> DemoController {
        DemoController(segments: [DemoSegment(name: "One", actions: [.character("a")]),
                                  DemoSegment(name: "Two", actions: [.character("b")]),
                                  DemoSegment(name: "Three", actions: [.character("c")])])
    }
    @discardableResult
    private func send(_ c: DemoController, _ kind: KeyboardInput.Kind, key: UInt16 = 0,
                      flags: KeyModifiers = [], pid: Int32 = 10, repeated: Bool = false) -> InputDecision {
        c.handle(KeyboardInput(kind: kind, keyCode: key, modifiers: flags, isRepeat: repeated), frontmostPID: pid)
    }
    private func toggle(_ c: DemoController, pid: Int32 = 10) {
        send(c, .down, key: 15, flags: .hotkey, pid: pid)
        send(c, .up, key: 15, pid: pid)
    }
    func testOrderWaitingCrossAppBindingAndFinalCompletion() {
        let c = controller()
        toggle(c)
        XCTAssertEqual(send(c, .down).action, .character("a"))
        send(c, .up)
        XCTAssertEqual(c.state, .waiting)
        c.frontmostChanged(20)
        XCTAssertEqual(c.state, .waiting)
        XCTAssertTrue(send(c, .down, pid: 20).suppress)
        XCTAssertNil(send(c, .down, pid: 20, repeated: true).action)
        send(c, .up, pid: 20)
        c.advanceSegment(frontmostPID: 20, modifiers: .command)
        XCTAssertEqual(c.targetPID, 20)
        XCTAssertEqual(c.state, .arming)
        XCTAssertNil(send(c, .down, flags: .command, pid: 20).action)
        send(c, .modifiers, pid: 20)
        XCTAssertEqual(c.state, .arming) // Held ordinary key must also release.
        send(c, .up, pid: 20)
        XCTAssertEqual(c.state, .playing)
        c.advanceSegment(frontmostPID: 20, modifiers: []) // Repeated click cannot skip.
        XCTAssertEqual(c.segmentIndex, 1)
        XCTAssertEqual(send(c, .down, pid: 20).action, .character("b"))
        send(c, .up, pid: 20)
        c.advanceSegment(frontmostPID: 30, modifiers: [])
        XCTAssertEqual(send(c, .down, pid: 30).action, .character("c"))
        send(c, .up, pid: 30)
        XCTAssertEqual(c.state, .complete)
        XCTAssertEqual(c.position, 3)
        c.advanceSegment(frontmostPID: 30, modifiers: [])
        XCTAssertNil(send(c, .down, pid: 30).action)
        XCTAssertEqual(c.segmentIndex, 2)
        send(c, .up, pid: 30)
        toggle(c, pid: 30)
        toggle(c, pid: 30)
        XCTAssertEqual(c.segmentIndex, 0)
        XCTAssertEqual(send(c, .down, pid: 30).action, .character("a"))
    }
    func testSwitchingApplicationsDuringPlaybackStillCancels() {
        let c = controller()
        toggle(c)
        XCTAssertNil(send(c, .down, pid: 20).action)
        XCTAssertEqual(c.state, .off)
    }
    func testCancelledGateDoesNotAdvanceOnLaterRelease() {
        let c = controller()
        toggle(c)
        send(c, .down); send(c, .up)
        c.advanceSegment(frontmostPID: 10, modifiers: .command)
        toggle(c)
        send(c, .modifiers)
        XCTAssertEqual(c.state, .off)
        XCTAssertEqual(c.segmentIndex, 0)
    }
    func testGestureRequiresMatchingClickOnlyWhileWaiting() throws {
        var gesture = SegmentAdvanceGesture()
        XCTAssertFalse(gesture.handle(.down, waiting: true, modifiers: []))
        XCTAssertFalse(gesture.handle(.up, waiting: true, modifiers: []))
        XCTAssertFalse(gesture.handle(.down, waiting: true, modifiers: [.command, .shift]))
        XCTAssertFalse(gesture.handle(.up, waiting: true, modifiers: []))
        XCTAssertFalse(gesture.handle(.down, waiting: true, modifiers: .command))
        XCTAssertFalse(gesture.handle(.dragged, waiting: true, modifiers: .command))
        XCTAssertFalse(gesture.handle(.up, waiting: true, modifiers: .command))
        XCTAssertFalse(gesture.handle(.down, waiting: false, modifiers: .command))
        XCTAssertFalse(gesture.handle(.up, waiting: true, modifiers: .command))
        XCTAssertFalse(gesture.handle(.down, waiting: true, modifiers: .command))
        XCTAssertTrue(gesture.handle(.up, waiting: true, modifiers: []))
        XCTAssertFalse(gesture.handle(.up, waiting: true, modifiers: []))
        XCTAssertFalse(gesture.handle(.down, waiting: true, modifiers: .command, clickCount: 2))
        XCTAssertFalse(gesture.handle(.up, waiting: true, modifiers: []))
        gesture.shortcut = try SegmentAdvanceShortcut("alt+shift+click")
        XCTAssertFalse(gesture.handle(.down, waiting: true, modifiers: [.option, .shift]))
        XCTAssertTrue(gesture.handle(.up, waiting: true, modifiers: [.option, .shift]))
    }
    func testAdvanceSettingsAndCLIParsingRemainIndependentOfToggle() throws {
        XCTAssertEqual(try SegmentAdvanceShortcut("command+click").label, "cmd+click")
        for bad in ["click", "cmd+cmd+click", "cmd+r", "cmd++click", "fn+click"] {
            XCTAssertThrowsError(try SegmentAdvanceShortcut(bad))
        }
        let legacy = try JSONDecoder().decode(RuntimeSettings.self, from: Data(#"{"hotkey":"ctrl+option+k"}"#.utf8))
        XCTAssertEqual(legacy.advanceShortcut, "cmd+click")
        XCTAssertEqual(legacy.hotkey, "ctrl+option+k")
        let exe = URL(fileURLWithPath: "/tmp/cuetap")
        let options = try CommandOptions(arguments: ["advance", "set", "alt+click", "--json"], executableURL: exe)
        XCTAssertEqual(options.mode, .advanceSet)
        XCTAssertEqual(options.hotkey, "option+click")
    }
    func testVersionTwoPreservesSegmentsAndVersionOneStaysSingle() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("html-demo.json")
        let script = try DemoScript.load(from: url)
        XCTAssertEqual(script.segments.count, 3)
        XCTAssertEqual(script.segments.map(\.actions).map(\.count), [38, 38, 39])
        XCTAssertEqual(script.actions.count, 115)
        XCTAssertEqual(try ExampleFixture.load().segments.count, 1)
    }
    func testVersionTwoRejectsMixedEmptyUnknownAndOversizedSegments() throws {
        let action: [String: Any] = ["type": "text", "value": "a"]
        let segment: [String: Any] = ["name": "One", "actions": [action]]
        func decode(_ object: [String: Any]) throws -> DemoScript {
            try DemoScript.decode(JSONSerialization.data(withJSONObject: object))
        }
        for object: [String: Any] in [
            ["version": 2, "name": "Test", "segments": []],
            ["version": 2, "name": "Test", "segments": [segment], "actions": [action]],
            ["version": 1, "name": "Test", "segments": [segment], "actions": [action]],
            ["version": 2, "name": "Test", "segments": [["name": "", "actions": [action]]]],
            ["version": 2, "name": "Test", "segments": [["name": "X", "actions": []]]],
            ["version": 2, "name": "Test", "segments": [["name": "X", "actions": [action], "unknown": true]]],
            ["version": 2, "name": "Test", "segments": [segment, ["name": "X", "actions": [["type": "key", "key": "left", "count": 100000]]]]]
        ] { XCTAssertThrowsError(try decode(object)) }
    }
    func testDirectoryDiscoveryIsolatedInvalidFilesAndRescans() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = RuntimePaths(environment: ["CUETAP_HOME": root.path])
        try paths.prepareConfigurations()
        let store = ConfigurationStore(paths: paths)
        XCTAssertTrue(try store.list(selectedPath: nil).isEmpty)
        let valid = paths.configurations.appendingPathComponent("valid.json")
        try FileManager.default.copyItem(at: ExampleFixture.url, to: valid)
        let bad = paths.configurations.appendingPathComponent("invalid.json")
        try Data("not JSON".utf8).write(to: bad)
        let entries = try store.list(selectedPath: valid.path)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first { $0.id == "valid" }?.selected, true)
        XCTAssertNotNil(entries.first { $0.id == "invalid" }?.error)
        XCTAssertEqual(try store.resolve(ExampleFixture.load().name).resolvingSymlinksInPath(), valid.resolvingSymlinksInPath())
        try FileManager.default.removeItem(at: valid)
        XCTAssertEqual(try store.list(selectedPath: nil).count, 1)
    }
}
