import XCTest

final class DemoHotkeyTests: XCTestCase {
    func testAliasesNormalizeAndResolvePhysicalKey() throws {
        let value = try DemoHotkey("CONTROL+ALT+K")
        XCTAssertEqual(value.label, "ctrl+option+k")
        XCTAssertEqual(value.keyCode, 40)
        XCTAssertEqual(value.modifiers, [.control, .option])
        XCTAssertEqual(try DemoHotkey("shift+command+r"), .default)
    }
    func testUnsafeOrMalformedCombinationsAreRejected() {
        for value in ["r", "cmd+r", "shift+option+r", "cmd+cmd+r", "cmd+shift+", "cmd+shift+中", "cmd+shift+escape", "cmd+shift+q", "ctrl+cmd+q"] {
            XCTAssertThrowsError(try DemoHotkey(value), value)
        }
    }
    func testConfiguredHotkeyReplacesDefaultAndWaitsForItsOwnRelease() throws {
        let hotkey = try DemoHotkey("ctrl+option+k")
        let controller = DemoController(actions: [.character("Z")], hotkey: hotkey)
        func event(_ kind: KeyboardInput.Kind, _ code: UInt16, _ flags: KeyModifiers = []) -> InputDecision {
            controller.handle(KeyboardInput(kind: kind, keyCode: code, modifiers: flags), frontmostPID: 1)
        }
        XCTAssertFalse(event(.down, 15, .hotkey).suppress)
        _ = event(.up, 15)
        XCTAssertTrue(event(.down, 40, hotkey.modifiers).suppress)
        XCTAssertEqual(controller.state, .arming)
        XCTAssertNil(event(.down, 1, hotkey.modifiers).action)
        _ = event(.up, 1)
        _ = event(.up, 40)
        XCTAssertEqual(event(.down, 0).action, .character("Z"))
        _ = event(.up, 0)
        XCTAssertEqual(controller.state, .complete)
        _ = event(.down, 40, hotkey.modifiers)
        _ = event(.up, 40)
        XCTAssertEqual(controller.state, .off)
    }
    func testReconfigurationIsRejectedUntilInterceptedKeysRelease() throws {
        let controller = DemoController(actions: [.character("A")])
        _ = controller.handle(KeyboardInput(kind: .down, keyCode: 15, modifiers: .hotkey), frontmostPID: 1)
        XCTAssertThrowsError(try controller.configure(actions: [], hotkey: .default))
        controller.cancel()
        XCTAssertThrowsError(try controller.configure(actions: [], hotkey: .default))
        _ = controller.handle(KeyboardInput(kind: .up, keyCode: 15), frontmostPID: 1)
        try controller.configure(actions: [.character("B")], hotkey: .default)
        XCTAssertEqual(controller.position, 0)
    }
}
