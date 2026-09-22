import Foundation

/// One expected/actual pair of a diff run, typically one segment's target and scratch file.
struct FileComparison: Codable {
    let expected: String
    let actual: String
    let comparison: TextComparison
}

struct DiffCommand {
    let pairs: [(expected: String, actual: String)]

    init(pairs: [(expected: String, actual: String)]) { self.pairs = pairs }
    init(expectedPath: String, actualPath: String) { pairs = [(expectedPath, actualPath)] }

    func run() throws -> ControlResponse {
        func read(_ path: String) throws -> (String, String) {
            let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
            do { return (url.path, try String(contentsOf: url, encoding: .utf8)) }
            catch { throw ControlError("target_unreadable", "Cannot read \(url.path) as UTF-8 text: \(error)") }
        }
        var results: [FileComparison] = []
        for pair in pairs {
            let (expectedPath, expected) = try read(pair.expected)
            let (actualPath, actual) = try read(pair.actual)
            results.append(FileComparison(expected: expectedPath, actual: actualPath, comparison: TextComparison.compare(expected: expected, actual: actual)))
        }
        let mismatches = results.filter { !$0.comparison.identical }
        var response: ControlResponse
        if mismatches.isEmpty {
            let trailing = results.map(\.comparison.trailingNewline)
            response = ControlResponse(message: results.count == 1
                ? "The files match character for character. Trailing newline: \(trailing[0])."
                : "All \(results.count) pairs match character for character. Trailing newline: \(trailing.joined(separator: ", ")).")
        } else {
            let details = mismatches.map { result -> String in
                let c = result.comparison
                let which = results.count == 1 ? "" : "\(result.actual): "
                return "\(which)first difference at line \(c.line ?? 0), column \(c.column ?? 0). Expected \(c.expected.map { "\"\($0)\"" } ?? "no line"), actual \(c.actual.map { "\"\($0)\"" } ?? "no line"). Trailing newline: \(c.trailingNewline)."
            }
            let summary = results.count == 1 ? "" : "\(mismatches.count) of \(results.count) pairs differ. "
            response = ControlResponse.failure(ControlError("text_mismatch", summary + details.joined(separator: " ")))
        }
        response.comparison = mismatches.first?.comparison ?? results.first?.comparison
        response.comparisons = results
        return response
    }
}
