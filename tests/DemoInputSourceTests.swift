import XCTest

final class DemoInputSourceTests: XCTestCase {
    private final class Access: InputSourceAccess {
        var current = "Chinese"
        var selections: [String] = []
        var failEnglishLookup = false
        var failedSelection: String?
        func currentID() throws -> String { current }
        func englishID() throws -> String {
            if failEnglishLookup { throw SessionError.unavailable("no English") }
            return "ABC"
        }
        func select(_ identifier: String) throws {
            selections.append(identifier)
            if identifier == failedSelection { throw SessionError.unavailable("selection failed") }
            current = identifier
        }
    }

    func testOffDoesNotChangeInputSource() throws {
        let access = Access()
        let source = DemoInputSource(access: access)
        try source.synchronize(active: false)
        XCTAssertEqual(access.current, "Chinese")
        XCTAssertTrue(access.selections.isEmpty)
    }

    func testEnableForcesEnglishAndDisableRestoresOriginal() throws {
        let access = Access()
        let source = DemoInputSource(access: access)
        try source.synchronize(active: true)
        XCTAssertEqual(access.current, "ABC")
        try source.synchronize(active: false)
        XCTAssertEqual(access.current, "Chinese")
        try source.restore()
        XCTAssertEqual(access.selections, ["ABC", "Chinese"])
    }

    func testRepeatedActiveChecksPreserveFirstSnapshotAndCorrectExternalChanges() throws {
        let access = Access()
        let source = DemoInputSource(access: access)
        try source.synchronize(active: true)
        try source.synchronize(active: true)
        access.current = "Japanese"
        try source.synchronize(active: true)
        XCTAssertEqual(access.current, "ABC")
        try source.restore()
        XCTAssertEqual(access.current, "Chinese")
        XCTAssertEqual(access.selections, ["ABC", "ABC", "Chinese"])
    }

    func testEveryNewDemoCapturesFreshOriginal() throws {
        let access = Access()
        let source = DemoInputSource(access: access)
        try source.synchronize(active: true)
        try source.restore()
        access.current = "Japanese"
        try source.synchronize(active: true)
        try source.restore()
        XCTAssertEqual(access.current, "Japanese")
    }

    func testAlreadyEnglishRequiresNoSelections() throws {
        let access = Access()
        access.current = "ABC"
        let source = DemoInputSource(access: access)
        try source.synchronize(active: true)
        try source.restore()
        XCTAssertTrue(access.selections.isEmpty)
    }

    func testMissingEnglishAndFailedSelectionDoNotLoseOriginal() throws {
        let access = Access()
        let source = DemoInputSource(access: access)
        access.failEnglishLookup = true
        XCTAssertThrowsError(try source.synchronize(active: true))
        XCTAssertEqual(access.current, "Chinese")
        access.failEnglishLookup = false
        access.failedSelection = "ABC"
        XCTAssertThrowsError(try source.synchronize(active: true))
        try source.restore()
        XCTAssertEqual(access.current, "Chinese")
    }

    func testFailedRestoreCanBeRetried() throws {
        let access = Access()
        let source = DemoInputSource(access: access)
        try source.synchronize(active: true)
        access.failedSelection = "Chinese"
        XCTAssertThrowsError(try source.restore())
        access.failedSelection = nil
        try source.restore()
        XCTAssertEqual(access.current, "Chinese")
    }

    func testReleaseRestoresOwnedInputSource() throws {
        let access = Access()
        var source: DemoInputSource? = DemoInputSource(access: access)
        try source?.synchronize(active: true)
        source = nil
        XCTAssertEqual(access.current, "Chinese")
    }
}
