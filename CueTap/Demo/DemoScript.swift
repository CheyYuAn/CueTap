import Foundation

enum DemoAction: Equatable {
    case character(Character)
    case left, right, enter, tab
}

struct ScriptError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

/// Expand configuration once before installing the event tap. Playback has no file I/O.
struct DemoScript {
    let name: String
    let actions: [DemoAction]
    static let maximumActions = 100_000
    static let maximumBytes = 1_048_576

    static func load(from url: URL) throws -> DemoScript {
        do {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            return try decode(file.read(upToCount: maximumBytes + 1) ?? Data())
        } catch { throw ScriptError("配置文件 \(url.path)：\(error)") }
    }

    static func decode(_ data: Data) throws -> DemoScript {
        guard data.count <= maximumBytes else { throw ScriptError("文件不能超过 1 MiB。") }
        let document: Document
        do { document = try JSONDecoder().decode(Document.self, from: data) }
        catch let error as DecodingError {
            let context: DecodingError.Context
            switch error {
            case .keyNotFound(let key, let detail):
                throw ScriptError("\(path(detail.codingPath)).\(key.stringValue)：缺少必填字段。")
            case .typeMismatch(_, let detail), .valueNotFound(_, let detail), .dataCorrupted(let detail):
                context = detail
            @unknown default: throw ScriptError("JSON 无法解析。")
            }
            throw ScriptError("\(path(context.codingPath))：JSON 格式或字段类型错误，\(context.debugDescription)")
        }
        guard document.version == 1 else { throw ScriptError("version：只支持版本 1。") }
        guard !document.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScriptError("name：名称不能为空。")
        }
        var actions: [DemoAction] = []
        for (index, entry) in document.actions.enumerated() {
            let location = "actions[\(index)]"
            let expanded: [DemoAction]
            switch entry.type {
            case "text":
                guard let value = entry.value, !value.isEmpty, entry.key == nil, entry.count == nil else {
                    throw ScriptError("\(location)：text 只允许 type 和非空 value。")
                }
                let normalized = value.replacingOccurrences(of: "\r\n", with: "\n")
                guard normalized.count <= maximumActions - actions.count else {
                    throw ScriptError("\(location)：展开后不能超过 \(maximumActions) 个动作。")
                }
                expanded = try normalized.enumerated().map { offset, character in
                    if character == "\n" { return .enter }
                    if character == "\t" { return .tab }
                    guard USKeyboardLayout.stroke(for: character) != nil else {
                        throw ScriptError("\(location).value：第 \(offset + 1) 个字符不支持；仅支持可打印 ASCII、换行和 Tab。")
                    }
                    return .character(character)
                }
            case "key":
                guard let key = entry.key, entry.value == nil else {
                    throw ScriptError("\(location)：key 只允许 type、key 和可选 count。")
                }
                let action: DemoAction
                switch key {
                case "left": action = .left
                case "right": action = .right
                case "enter": action = .enter
                case "tab": action = .tab
                default: throw ScriptError("\(location).key：只支持 left、right、enter、tab。")
                }
                let count = entry.count ?? 1
                guard count > 0, count <= maximumActions - actions.count else {
                    throw ScriptError("\(location).count：必须是正整数，展开后不能超过 \(maximumActions) 个动作。")
                }
                expanded = Array(repeating: action, count: count)
            default: throw ScriptError("\(location).type：只支持 text 或 key。")
            }
            actions.append(contentsOf: expanded)
        }
        guard !actions.isEmpty else { throw ScriptError("actions：动作列表不能为空。") }
        return DemoScript(name: document.name, actions: actions)
    }

    private static func path(_ keys: [CodingKey]) -> String {
        keys.reduce("配置") { result, key in
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
                throw ScriptError("\(path(decoder.codingPath)).\(field.stringValue)：未知字段。")
            }
            if try fields.decodeNil(forKey: field) {
                throw ScriptError("\(path(decoder.codingPath)).\(field.stringValue)：不允许 null。")
            }
        }
    }

    private struct Document: Decodable {
        let version: Int
        let name: String
        let actions: [Entry]
        enum CodingKeys: String, CodingKey { case version, name, actions }
        init(from decoder: Decoder) throws {
            try validateFields(decoder, allowed: ["version", "name", "actions"])
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            version = try fields.decode(Int.self, forKey: .version)
            name = try fields.decode(String.self, forKey: .name)
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
                    throw ScriptError("\(path(decoder.codingPath)).count：必须是 1 至 \(maximumActions) 的整数。")
                }
                count = Int(number)
            } else { count = nil }
        }
    }
}
