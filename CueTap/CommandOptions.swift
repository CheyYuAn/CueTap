import Foundation

struct CommandOptions {
    enum Mode { case run, check, validate, help }
    let mode: Mode
    let scriptURL: URL

    init(arguments: [String], executableURL: URL) throws {
        var mode: Mode = .run
        var path: String?
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--script":
                guard path == nil, index + 1 < arguments.count,
                      !arguments[index + 1].isEmpty, !arguments[index + 1].hasPrefix("--") else {
                    throw ScriptError("--script 必须且只能指定一个文件路径。")
                }
                index += 1
                path = arguments[index]
            case "--check", "--validate", "--help":
                guard mode == .run else { throw ScriptError("--check、--validate、--help 不能重复或组合使用。") }
                mode = arguments[index] == "--check" ? .check : arguments[index] == "--validate" ? .validate : .help
            default: throw ScriptError("未知参数：\(arguments[index])。运行 cuetap --help 查看用法。")
            }
            index += 1
        }
        if path != nil && (mode == .check || mode == .help) {
            throw ScriptError("--script 可用于启动或 --validate；--check 只检查系统权限。")
        }
        self.mode = mode
        if let path {
            scriptURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        } else {
            scriptURL = executableURL.resolvingSymlinksInPath().deletingLastPathComponent()
                .appendingPathComponent("html-demo.json")
        }
    }
}
