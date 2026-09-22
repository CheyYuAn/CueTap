import Foundation
import XCTest

final class TextDiffTests: XCTestCase {
    func testIdenticalTextsAndTrailingNewlineDifferences() {
        XCTAssertTrue(TextComparison.compare(expected: "a\nb\n", actual: "a\nb\n").identical)
        let result = TextComparison.compare(expected: "a\nb\n", actual: "a\r\nb")
        XCTAssertTrue(result.identical, "CRLF and the final newline are not counted as differences")
        XCTAssertEqual(result.trailingNewline, "expected ends with a newline, actual does not")
    }

    func testFirstDifferenceIsReportedWithLineAndColumn() {
        let result = TextComparison.compare(expected: "int x;\n    if (a) b;\n}", actual: "int x;\n  if (a) b;\n}")
        XCTAssertFalse(result.identical)
        XCTAssertEqual(result.line, 2)
        XCTAssertEqual(result.column, 3)
        XCTAssertEqual(result.expected, "    if (a) b;")
        XCTAssertEqual(result.actual, "  if (a) b;")
    }

    func testMissingLinesAreReportedAsAbsent() {
        let result = TextComparison.compare(expected: "a\nb", actual: "a")
        XCTAssertEqual(result.line, 2)
        XCTAssertEqual(result.column, 1)
        XCTAssertEqual(result.expected, "b")
        XCTAssertNil(result.actual)
    }
}
