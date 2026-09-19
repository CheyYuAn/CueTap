import Foundation

struct ConfigurationCommand: Codable {
    enum Operation: String, Codable { case list, use, rename, export, remove }
    let operation: Operation
    var selector: String?
    var value: String?

    init(arguments: [String]) throws {
        guard let first = arguments.first, let operation = Operation(rawValue: first) else {
            throw ScriptError("Usage: cuetap config list | use ID | rename ID NAME | export ID FILE | remove ID")
        }
        let count = operation == .list ? 1 : [.rename, .export].contains(operation) ? 3 : 2
        guard arguments.count == count, arguments.dropFirst().allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ScriptError("Invalid arguments for config \(operation.rawValue). Run cuetap help.")
        }
        self.operation = operation
        selector = count >= 2 ? arguments[1] : nil
        if count == 3 {
            value = operation == .export
                ? URL(fileURLWithPath: (arguments[2] as NSString).expandingTildeInPath).standardizedFileURL.path
                : arguments[2]
        }
    }
}

struct ConfigurationInfo: Codable {
    let id: String
    let name: String
    let description: String
    let path: String
    let actionCount: Int
    let selected: Bool
    var segmentCount: Int = 1
    var error: String?
}

extension ConfigurationStore {
    func listOrExport(_ command: ConfigurationCommand, selectedPath: String?) throws -> ControlResponse {
        if command.operation == .list {
            return ControlResponse(message: "Saved configurations.", configurations: try list(selectedPath: selectedPath))
        }
        guard command.operation == .export, let selector = command.selector,
              let destination = command.value, destination.hasPrefix("/") else {
            throw ControlError("invalid_request", "Expected config list or config export ID FILE.")
        }
        try export(resolve(selector), to: URL(fileURLWithPath: destination))
        return ControlResponse(message: "Configuration exported.", outputPath: destination)
    }

    /// The managed filename (without .json) is the stable ID; renaming changes only JSON metadata.
    func id(for url: URL) -> String? {
        guard url.resolvingSymlinksInPath().deletingLastPathComponent().path == paths.configurations.resolvingSymlinksInPath().path else { return nil }
        return url.deletingPathExtension().lastPathComponent
    }

    func info(for url: URL, script: DemoScript, selectedPath: String?) -> ConfigurationInfo {
        ConfigurationInfo(id: url.deletingPathExtension().lastPathComponent, name: script.name,
                          description: script.description, path: url.path, actionCount: script.actions.count,
                          selected: sameFile(url, selectedPath), segmentCount: script.segments.count)
    }

    func list(selectedPath: String?) throws -> [ConfigurationInfo] {
        try files().map { url in
            do { return info(for: url, script: try DemoScript.load(from: url), selectedPath: selectedPath) }
            catch {
                return ConfigurationInfo(id: url.deletingPathExtension().lastPathComponent,
                                         name: url.lastPathComponent, description: "", path: url.path,
                                         actionCount: 0, selected: sameFile(url, selectedPath),
                                         segmentCount: 0, error: String(describing: error))
            }
        }
    }

    func resolve(_ selector: String) throws -> URL {
        let urls = try files()
        if let exact = urls.first(where: { $0.deletingPathExtension().lastPathComponent == selector }) { return exact }
        let matches = urls.filter { (try? DemoScript.load(from: $0).name) == selector }
        guard matches.count <= 1 else { throw ControlError("ambiguous_configuration", "More than one configuration is named \(selector). Use an ID from config list.") }
        guard let match = matches.first else { throw ControlError("configuration_not_found", "No configuration matches \(selector). Run config list.") }
        return match
    }

    func rename(_ url: URL, to name: String) throws -> DemoScript {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ControlError("invalid_name", "Configuration name must not be blank.")
        }
        let file = try DemoScript.readFile(from: url)
        var document = try JSONSerialization.jsonObject(with: file.data) as! [String: Any]
        document["name"] = name
        let data = try JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        let script = try DemoScript.decode(data)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return script
    }

    func export(_ url: URL, to destination: URL) throws {
        guard destination.resolvingSymlinksInPath().deletingLastPathComponent().path != paths.configurations.resolvingSymlinksInPath().path else {
            throw ControlError("invalid_destination", "Export outside the managed configurations directory.")
        }
        guard (try? FileManager.default.attributesOfItem(atPath: destination.path)) == nil else {
            throw ControlError("destination_exists", "Export destination already exists: \(destination.path). Choose a new path.")
        }
        let file = try DemoScript.readFile(from: url)
        try file.data.write(to: destination, options: .withoutOverwriting)
    }

    func remove(_ url: URL, selectedPath: String?) throws {
        guard !sameFile(url, selectedPath) else {
            throw ControlError("configuration_in_use", "This configuration is selected. Use another configuration before removing it.")
        }
        try FileManager.default.removeItem(at: url)
    }

    private func sameFile(_ url: URL, _ path: String?) -> Bool {
        guard let path else { return false }
        return url.resolvingSymlinksInPath().path == URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    private func files() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: paths.configurations.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: paths.configurations, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            .filter {
                let values = try $0.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                return $0.pathExtension.lowercased() == "json" && values.isRegularFile == true && values.isSymbolicLink != true
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
