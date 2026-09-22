import Foundation

/// Finds a language's configuration file the way VS Code does: every extension's package.json lists
/// the languages it contributes and where their language-configuration.json lives. Built-in extensions
/// are searched before user-installed ones.
enum VSCodeLanguages {
    static var extensionRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [URL(fileURLWithPath: "/Applications/Visual Studio Code.app/Contents/Resources/app/extensions"),
                home.appendingPathComponent("Applications/Visual Studio Code.app/Contents/Resources/app/extensions"),
                home.appendingPathComponent(".vscode/extensions")]
    }

    struct Definition {
        let id: String
        let configuration: URL
        let extensions: [String]
    }

    static func configurationURL(for languageId: String, roots: [URL]? = nil) -> URL? {
        definitions(roots: roots, matching: languageId).first?.configuration
    }

    /// Every language with a configuration file, in search order; the first definition of an id wins,
    /// which is what `configurationURL` returns.
    static func definitions(roots: [URL]? = nil, matching languageId: String? = nil) -> [Definition] {
        var result: [Definition] = []
        var seen: Set<String> = []
        for root in roots ?? extensionRoots {
            guard let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for folder in folders.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
                let manifest = folder.appendingPathComponent("package.json")
                guard let data = try? Data(contentsOf: manifest),
                      let object = try? JSONSerialization.jsonObject(with: Data(EditorRules.stripComments(String(decoding: data, as: UTF8.self)).utf8)),
                      let contributes = (object as? [String: Any])?["contributes"] as? [String: Any],
                      let languages = contributes["languages"] as? [[String: Any]] else { continue }
                for language in languages {
                    guard let id = language["id"] as? String, languageId == nil || id == languageId,
                          let path = language["configuration"] as? String, !seen.contains(id) else { continue }
                    let url = folder.appendingPathComponent(path).standardizedFileURL
                    guard FileManager.default.fileExists(atPath: url.path) else { continue }
                    seen.insert(id)
                    result.append(Definition(id: id, configuration: url, extensions: language["extensions"] as? [String] ?? []))
                    if languageId != nil { return result }
                }
            }
        }
        return result
    }
}
