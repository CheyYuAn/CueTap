import XCTest

final class DemoControllerTests: XCTestCase {
    private var actions: [DemoAction] = []
    override func setUpWithError() throws { actions = try ExampleFixture.load().actions }

    @discardableResult
    private func send(_ controller: DemoController, _ kind: KeyboardInput.Kind, _ code: UInt16 = 0,
                      flags: KeyModifiers = [], repeatKey: Bool = false, synthetic: Bool = false,
                      pid: Int32? = 100) -> InputDecision {
        controller.handle(KeyboardInput(kind: kind, keyCode: code, modifiers: flags,
                                        isRepeat: repeatKey, isSynthetic: synthetic), frontmostPID: pid)
    }

    private func toggle(_ controller: DemoController) {
        send(controller, .modifiers, 55, flags: .command)
        send(controller, .modifiers, 56, flags: .hotkey)
        XCTAssertTrue(send(controller, .down, 15, flags: .hotkey).suppress)
        XCTAssertTrue(send(controller, .up, 15, flags: .hotkey).suppress)
        send(controller, .modifiers, 56, flags: .command)
        send(controller, .modifiers, 55)
    }

    func testFixedScriptProducesExpectedTextWithPlainEditorSemantics() {
        var text: [Character] = []
        var cursor = 0
        var leftCount = 0
        for action in actions {
            switch action {
            case .character(let char): text.insert(char, at: cursor); cursor += 1
            case .tab: text.insert("\t", at: cursor); cursor += 1
            case .enter: text.insert("\n", at: cursor); cursor += 1
            case .left: cursor -= 1; leftCount += 1
            case .right: cursor += 1
            }
        }
        XCTAssertEqual(actions.count, 38)
        XCTAssertEqual(leftCount, 7)
        XCTAssertEqual(String(text), "<div class:\"body\">\nhello</div>")
        XCTAssertEqual(cursor, text.count - 6)
        // No indentation text is included; that remains the actual editor's behavior.
    }

    func testOffPassesNormalKeysAndModifiers() {
        let controller = DemoController(actions: actions)
        XCTAssertFalse(send(controller, .down).suppress)
        XCTAssertFalse(send(controller, .up).suppress)
        XCTAssertFalse(send(controller, .modifiers, 56, flags: .shift).suppress)
        XCTAssertEqual(controller.position, 0)
    }

    func testHotkeyMustFullyReleaseBeforeProgress() {
        let controller = DemoController(actions: actions)
        XCTAssertTrue(send(controller, .down, 15, flags: .hotkey).neutralizeModifiers)
        XCTAssertEqual(controller.state, .arming)
        XCTAssertNil(send(controller, .down, 1, flags: .hotkey).action)
        send(controller, .up, 1, flags: .hotkey)
        send(controller, .up, 15, flags: .hotkey)
        XCTAssertEqual(controller.state, .arming)
        send(controller, .modifiers, 56, flags: .command)
        XCTAssertEqual(controller.state, .arming)
        send(controller, .modifiers, 55)
        XCTAssertEqual(controller.state, .playing)
        XCTAssertEqual(send(controller, .down).action, .character("<"))
    }

    func testReleasingModifiersBeforeRAlsoArmsCorrectly() {
        let controller = DemoController(actions: actions)
        send(controller, .down, 15, flags: .hotkey)
        send(controller, .modifiers, 55)
        XCTAssertEqual(controller.state, .arming)
        send(controller, .up, 15)
        XCTAssertEqual(controller.state, .playing)
        XCTAssertEqual(controller.position, 0)
    }

    func testOnlyFreshKeyDownAdvancesAndPhysicalKeyDoesNotChooseOutput() {
        let controller = DemoController(actions: actions)
        toggle(controller)
        XCTAssertEqual(send(controller, .down, 51).action, .character("<")) // backspace
        XCTAssertNil(send(controller, .down, 51, repeatKey: true).action)
        XCTAssertNil(send(controller, .down, 51).action)
        XCTAssertNil(send(controller, .up, 51).action)
        XCTAssertEqual(send(controller, .down, 36).action, .character("d")) // return
        XCTAssertEqual(controller.position, 2)
    }

    func testSyntheticEventsNeitherAdvanceNorPolluteHeldKeyState() {
        let controller = DemoController(actions: actions)
        toggle(controller)
        XCTAssertFalse(send(controller, .down, 0, synthetic: true).suppress)
        XCTAssertEqual(controller.position, 0)
        XCTAssertEqual(send(controller, .down, 0).action, .character("<"))
    }

    func testModifiersAloneDoNotAdvanceAndRecordedActionIgnoresThem() {
        let controller = DemoController(actions: actions)
        toggle(controller)
        XCTAssertTrue(send(controller, .modifiers, 56, flags: .shift).suppress)
        XCTAssertEqual(controller.position, 0)
        XCTAssertEqual(send(controller, .down, 0, flags: .shift).action, .character("<"))
    }

    func testEntireScriptInOrderAndCompletionContinuesSuppressing() {
        let controller = DemoController(actions: actions)
        toggle(controller)
        var received: [DemoAction] = []
        for index in 0..<actions.count {
            let code = UInt16(index % 10)
            let result = send(controller, .down, code)
            XCTAssertTrue(result.suppress)
            if let action = result.action { received.append(action) }
            XCTAssertTrue(send(controller, .up, code).suppress)
        }
        XCTAssertEqual(received, actions)
        XCTAssertEqual(controller.state, .complete)
        XCTAssertTrue(send(controller, .down, 49).suppress)
        XCTAssertNil(send(controller, .down, 49, repeatKey: true).action)
        XCTAssertEqual(controller.position, 38)
        send(controller, .up, 49)
        toggle(controller)
        XCTAssertEqual(controller.state, .off)
        XCTAssertFalse(send(controller, .down, 49).suppress)
    }

    func testMidwayOffRestoresInputAndNextEnableStartsAtBeginning() {
        let controller = DemoController(actions: actions)
        toggle(controller)
        send(controller, .down)
        send(controller, .up)
        toggle(controller)
        XCTAssertEqual(controller.state, .off)
        XCTAssertFalse(send(controller, .down, 1).suppress)
        send(controller, .up, 1)
        toggle(controller)
        XCTAssertEqual(send(controller, .down).action, .character("<"))
    }

    func testSuppressedKeyReleaseIsDrainedAfterTurningOff() {
        let controller = DemoController(actions: actions)
        toggle(controller)
        send(controller, .down, 0)
        toggle(controller)
        XCTAssertEqual(controller.state, .off)
        XCTAssertTrue(send(controller, .down, 0, repeatKey: true).suppress)
        XCTAssertTrue(send(controller, .up, 0).suppress)
        XCTAssertFalse(send(controller, .down, 0).suppress)
    }

    func testHotkeyAutoRepeatDoesNotRetoggle() {
        let controller = DemoController(actions: actions)
        send(controller, .down, 15, flags: .hotkey)
        send(controller, .down, 15, flags: .hotkey, repeatKey: true)
        XCTAssertEqual(controller.state, .arming)
    }

    func testDifferentAppCancelsWithoutSendingAnActionThere() {
        let controller = DemoController(actions: actions)
        toggle(controller)
        let result = send(controller, .down, 0, pid: 200)
        XCTAssertNil(result.action)
        XCTAssertFalse(result.suppress)
        XCTAssertEqual(controller.state, .off)
        XCTAssertNil(controller.targetPID)
    }

    func testCancellationStillDrainsPreviouslySuppressedKeys() {
        let controller = DemoController(actions: actions)
        toggle(controller)
        send(controller, .down, 0)
        controller.cancel()
        XCTAssertTrue(send(controller, .up, 0, pid: 200).suppress)
        XCTAssertFalse(send(controller, .down, 0, pid: 200).suppress)
    }

    func testHotkeyWithExtraModifierDoesNotToggle() {
        let controller = DemoController(actions: actions)
        XCTAssertFalse(send(controller, .down, 15, flags: [.command, .shift, .option]).suppress)
        XCTAssertEqual(controller.state, .off)
    }

    func testEmptyActionsFinishAfterHotkeyReleaseWithoutIndexing() {
        let controller = DemoController(actions: [])
        toggle(controller)
        XCTAssertEqual(controller.state, .complete)
        XCTAssertNil(send(controller, .down).action)
    }
}
