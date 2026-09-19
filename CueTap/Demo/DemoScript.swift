import Foundation

enum DemoAction: Equatable {
    case character(Character)
    case left, right, enter, tab
}

struct ScriptError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

/// Expand configuration before playback. Playback has no file I/O.
struct DemoSegment: Equatable {
    let name: String
    var description: String = ""
    let actions: [DemoAction]
}

struct DemoScript {
    let name: String
    var description: String = ""
    let segments: [DemoSegment]
    var actions: [DemoAction] { segments.flatMap(\.actions) }

    init(name: String, description: String = "", actions: [DemoAction]) {
        self.init(name: name, description: description, segments: [DemoSegment(name: name, actions: actions)])
    }
    init(name: String, description: String = "", segments: [DemoSegment]) {
        self.name = name
        self.description = description
        self.segments = segments
    }
    static let maximumActions = 100_000
    static let maximumBytes = 1_048_576

    struct File {
        let data: Data
        let script: DemoScript
    }

    static func load(from url: URL) throws -> DemoScript {
        try readFile(from: url).script
    }

    /// Keep the validated bytes so importing cannot copy a different revision of the source.
    static func readFile(from url: URL) throws -> File {
        do {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let data = try file.read(upToCount: maximumBytes + 1) ?? Data()
            return File(data: data, script: try decode(data))
        } catch { throw ScriptError("Configuration \(url.path): \(error)") }
    }

    static func decode(_ data: Data) throws -> DemoScript {
        guard data.count <= maximumBytes else { throw ScriptError("File size must not exceed 1 MiB.") }
        let document: Document
        do { document = try JSONDecoder().decode(Document.self, from: data) }
        catch let error as DecodingError {
            let context: DecodingError.Context
            switch error {
            case .keyNotFound(let key, let detail):
                throw ScriptError("\(path(detail.codingPath)).\(key.stringValue): required field is missing.")
            case .typeMismatch(_, let detail), .valueNotFound(_, let detail), .dataCorrupted(let detail):
                context = detail
            @unknown default: throw ScriptError("Unable to parse JSON.")
            }
            throw ScriptError("\(path(context.codingPath)): invalid JSON or field type: \(context.debugDescription)")
        }
        guard [1, 2].contains(document.version) else { throw ScriptError("version: supported versions are 1 and 2.") }
        guard !document.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScriptError("name: must not be blank.")
        }
        let entries: [SegmentEntry]
        if document.version == 1 {
            guard let actions = document.actions, document.segments == nil else {
                throw ScriptError("version 1 requires actions and does not accept segments.")
            }
            entries = [SegmentEntry(name: document.name, description: "", actions: actions)]
        } else {
            guard let segments = document.segments, !segments.isEmpty, document.actions == nil else {
                throw ScriptError("version 2 requires nonempty segments and does not accept root actions.")
            }
            entries = segments
        }
        var total = 0
        let segments = try entries.enumerated().map { index, entry -> DemoSegment in
            guard !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ScriptError("segments[\(index)].name: must not be blank.")
            }
            let prefix = document.version == 1 ? "actions" : "segments[\(index)].actions"
            let actions = try expand(entry.actions, prefix: prefix, total: &total)
            return DemoSegment(name: entry.name, description: entry.description, actions: actions)
        }
        return DemoScript(name: document.name, description: document.description, segments: segments)
    }

    private static func expand(_ entries: [Entry], prefix: String, total: inout Int) throws -> [DemoAction] {
        var actions: [DemoAction] = []
        for (index, entry) in entries.enumerated() {
            let location = "\(prefix)[\(index)]"
            let expanded: [DemoAction]
            switch entry.type {
            case "text":
                guard let value = entry.value, !value.isEmpty, entry.key == nil, entry.count == nil else {
                    throw ScriptError("\(location): text requires only type and a nonempty value.")
                }
                let normalized = value.replacingOccurrences(of: "\r\n", with: "\n")
                guard normalized.count <= maximumActions - total - actions.count else {
                    throw ScriptError("\(location): expansion must not exceed \(maximumActions) actions.")
                }
                expanded = try normalized.enumerated().map { offset, character in
                    if character == "\n" { return .enter }
                    if character == "\t" { return .tab }
                    guard USKeyboardLayout.stroke(for: character) != nil else {
                        throw ScriptError("\(location).value: unsupported character at position \(offset + 1); use printable ASCII, newline or Tab.")
                    }
                    return .character(character)
                }
            case "key":
                guard let key = entry.key, entry.value == nil else {
                    throw ScriptError("\(location): key requires type, key and optional count only.")
                }
                let action: DemoAction
                switch key {
                case "left": action = .left
                case "right": action = .right
                case "enter": action = .enter
                case "tab": action = .tab
                default: throw ScriptError("\(location).key: supported keys are left, right, enter and tab.")
                }
                let count = entry.count ?? 1
                guard count > 0, count <= maximumActions - total - actions.count else {
                    throw ScriptError("\(location).count: count must be positive and total expansion must not exceed \(maximumActions) actions.")
                }
                expanded = Array(repeating: action, count: count)
            default: throw ScriptError("\(location).type: only text or key is supported.")
            }
            actions.append(contentsOf: expanded)
        }
        guard !actions.isEmpty else { throw ScriptError("\(prefix): the action list must not be empty.") }
        total += actions.count
        return actions
    }

    private static func path(_ keys: [CodingKey]) -> String {
        keys.reduce("configuration") { result, key in
            if let index = key.intValue { return result + "[\(index)]" }
            return result + "." + key.stringValue
        }
    }

    private struct Field: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    private static func validateFields(_ decoder: Decoder, allowed: Set<String>) throws {
        let fields = try decoder.container(keyedBy: Field.self)
        for field in fields.allKeys {
            guard allowed.contains(field.stringValue) else {
                throw ScriptError("\(path(decoder.codingPath)).\(field.stringValue): unknown field.")
            }
            if try fields.decodeNil(forKey: field) {
                throw ScriptError("\(path(decoder.codingPath)).\(field.stringValue): null is not allowed.")
            }
        }
    }

    private struct Document: Decodable {
        let version: Int
        let name: String
        let description: String
        let actions: [Entry]?
        let segments: [SegmentEntry]?
        enum CodingKeys: String, CodingKey { case version, name, description, actions, segments }
        init(from decoder: Decoder) throws {
            try validateFields(decoder, allowed: ["version", "name", "description", "actions", "segments"])
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            version = try fields.decode(Int.self, forKey: .version)
            name = try fields.decode(String.self, forKey: .name)
            description = try fields.decodeIfPresent(String.self, forKey: .description) ?? ""
            actions = try fields.decodeIfPresent([Entry].self, forKey: .actions)
            segments = try fields.decodeIfPresent([SegmentEntry].self, forKey: .segments)
        }
    }

    private struct SegmentEntry: Decodable {
        let name: String
        let description: String
        let actions: [Entry]
        enum CodingKeys: String, CodingKey { case name, description, actions }
        init(name: String, description: String, actions: [Entry]) {
            self.name = name; self.description = description; self.actions = actions
        }
        init(from decoder: Decoder) throws {
            try validateFields(decoder, allowed: ["name", "description", "actions"])
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            name = try fields.decode(String.self, forKey: .name)
            description = try fields.decodeIfPresent(String.self, forKey: .description) ?? ""
            actions = try fields.decode([Entry].self, forKey: .actions)
        }
    }

    private struct Entry: Decodable {
        let type: String
        let value: String?
        let key: String?
        let count: Int?
        enum CodingKeys: String, CodingKey { case type, value, key, count }
        init(from decoder: Decoder) throws {
            try validateFields(decoder, allowed: ["type", "value", "key", "count"])
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            type = try fields.decode(String.self, forKey: .type)
            value = try fields.decodeIfPresent(String.self, forKey: .value)
            key = try fields.decodeIfPresent(String.self, forKey: .key)
            if let number = try fields.decodeIfPresent(Double.self, forKey: .count) {
                guard number >= 1, number <= Double(maximumActions), number.rounded() == number else {
                    throw ScriptError("\(path(decoder.codingPath)).count: must be an integer between 1 and \(maximumActions).")
                }
                count = Int(number)
            } else { count = nil }
        }
    }
}
