import Foundation

/// Renders compiled segments as a version 2 configuration in the same layout as hand-written files.
enum ConfigurationWriter {
    static func render(name: String, description: String, segments: [(name: String, description: String, entries: [ActionEntry])]) -> String {
        var output = "{\n  \"version\": 2,\n  \"name\": \(quote(name)),\n  \"description\": \(quote(description)),\n  \"segments\": [\n"
        for (index, segment) in segments.enumerated() {
            output += "    {\n      \"name\": \(quote(segment.name)),\n      \"description\": \(quote(segment.description)),\n      \"actions\": [\n"
            for (position, entry) in segment.entries.enumerated() {
                switch entry {
                case .text(let value): output += "        { \"type\": \"text\", \"value\": \(quote(value)) }"
                case .key(let key, let count):
                    output += count == 1 ? "        { \"type\": \"key\", \"key\": \"\(key)\" }" : "        { \"type\": \"key\", \"key\": \"\(key)\", \"count\": \(count) }"
                }
                output += position == segment.entries.count - 1 ? "\n" : ",\n"
            }
            output += "      ]\n    }" + (index == segments.count - 1 ? "\n" : ",\n")
        }
        return output + "  ]\n}\n"
    }

    static func quote(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .withoutEscapingSlashes]) else { return "\"\"" }
        return String(decoding: data, as: UTF8.self)
    }
}
