import XCTest

final class CompletionLockTests: XCTestCase {
    func testExpiresOnceAfterTheDuration() {
        let lock = CompletionLock(duration: 0.05)
        let expired = expectation(description: "expired")
        var count = 0
        lock.sync(completed: true) { count += 1; expired.fulfill() }
        XCTAssertTrue(lock.isActive)
        // A second state change while the lock runs must not restart or duplicate it.
        lock.sync(completed: true) { count += 1 }
        wait(for: [expired], timeout: 2)
        XCTAssertEqual(count, 1)
        XCTAssertFalse(lock.isActive)
    }

    func testIncompleteStateDisarmsTheLock() {
        let lock = CompletionLock(duration: 0.05)
        lock.sync(completed: true) { XCTFail("The lock must not expire after the demo left the completed state.") }
        lock.sync(completed: false) { XCTFail("An incomplete state must not arm the lock.") }
        XCTAssertFalse(lock.isActive)
        let waited = expectation(description: "waited")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { waited.fulfill() }
        wait(for: [waited], timeout: 2)
    }

    func testCancelPreventsExpiry() {
        let lock = CompletionLock(duration: 0.05)
        lock.sync(completed: true) { XCTFail("A cancelled lock must not expire.") }
        lock.cancel()
        XCTAssertFalse(lock.isActive)
        let waited = expectation(description: "waited")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { waited.fulfill() }
        wait(for: [waited], timeout: 2)
    }

    func testDefaultDurationIsThreeSeconds() {
        XCTAssertEqual(CompletionLock.seconds, 3)
    }
}
