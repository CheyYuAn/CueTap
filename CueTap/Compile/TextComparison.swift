import Foundation

/// Character-level comparison of what a demo typed against the target text. A missing or extra
/// newline at the very end is reported separately, because editors add or drop it on save.
struct TextComparison: Codable {
    let identical: Bool
    let line: Int?
    let column: Int?
    let expected: String?
    let actual: String?
    let trailingNewline: String

    static func compare(expected: String, actual: String) -> TextComparison {
        func normalize(_ text: String) -> (lines: [String], newline: Bool) {
            var value = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            let newline = value.hasSuffix("\n")
            if newline { value.removeLast() }
            return (value.split(separator: "\n", omittingEmptySubsequences: false).map(String.init), newline)
        }
        let left = normalize(expected), right = normalize(actual)
        let trailing: String
        switch (left.newline, right.newline) {
        case (true, true), (false, false): trailing = "same"
        case (true, false): trailing = "expected ends with a newline, actual does not"
        case (false, true): trailing = "actual ends with a newline, expected does not"
        }
        for index in 0..<max(left.lines.count, right.lines.count) {
            let expectedLine = index < left.lines.count ? left.lines[index] : nil
            let actualLine = index < right.lines.count ? right.lines[index] : nil
            if expectedLine == actualLine { continue }
            var column = 1
            if let expectedLine, let actualLine {
                for (a, b) in zip(expectedLine, actualLine) { if a != b { break }; column += 1 }
            }
            return TextComparison(identical: false, line: index + 1, column: column, expected: expectedLine, actual: actualLine, trailingNewline: trailing)
        }
        return TextComparison(identical: true, line: nil, column: nil, expected: nil, actual: nil, trailingNewline: trailing)
    }
}
