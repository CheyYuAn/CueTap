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

struct DiffCommand {
    let expectedPath: String
    let actualPath: String

    func run() throws -> ControlResponse {
        func read(_ path: String) throws -> String {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
            do { return try String(contentsOf: url, encoding: .utf8) }
            catch { throw ControlError("target_unreadable", "Cannot read \(url.path) as UTF-8 text: \(error)") }
        }
        let comparison = TextComparison.compare(expected: try read(expectedPath), actual: try read(actualPath))
        if comparison.identical {
            var response = ControlResponse(message: "The files match character for character. Trailing newline: \(comparison.trailingNewline).")
            response.comparison = comparison
            return response
        }
        var response = ControlResponse.failure(ControlError("text_mismatch", "First difference at line \(comparison.line ?? 0), column \(comparison.column ?? 0). Expected \(comparison.expected.map { "\"\($0)\"" } ?? "no line"), actual \(comparison.actual.map { "\"\($0)\"" } ?? "no line"). Trailing newline: \(comparison.trailingNewline)."))
        response.comparison = comparison
        return response
    }
}
