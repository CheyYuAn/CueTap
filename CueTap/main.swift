import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
let wantsJSON = arguments.contains("--json")
func emit(_ response: ControlResponse) {
    if wantsJSON {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(response) { print(String(decoding: data, as: UTF8.self)) }
    } else {
        let text = ResponseFormatter.text(response)
        if response.ok { print(text) }
        else { FileHandle.standardError.write(Data(("CueTap: " + text + "\n").utf8)) }
    }
}
let executable = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath()
let options: CommandOptions
do { options = try CommandOptions(arguments: arguments, executableURL: executable) }
catch { emit(.failure(error)); exit(2) }
do {
    let response = try CommandRunner(executable: executable, paths: RuntimePaths()).execute(options)
    emit(response)
    if !response.ok { exit(1) }
} catch { emit(.failure(error)); exit(1) }
