import Foundation

/// One editor profile `cuetap compile` accepts, with where its rules come from and which file
/// extensions the language claims, so an agent can pick the profile from a file name.
struct ProfileInfo: Codable {
    let name: String
    let languageId: String
    /// `bundled` when the rules ship inside the executable, `installed` when an installed VS Code or
    /// one of its extensions defines the language, an installed definition being the one compile uses,
    /// and `built-in` for the plain profile, which has no rules at all.
    let source: String
    let rulesSource: String
    let extensions: [String]
    let tags: Bool
}

/// `cuetap profiles`: every `vscode-<language id>` that resolves on this machine.
struct ProfilesCommand {
    var roots: [URL]?

    func run() throws -> ControlResponse {
        var byLanguage: [String: ProfileInfo] = [:]
        for (language, snapshot) in BuiltInRules.snapshots {
            byLanguage[language] = ProfileInfo(name: "vscode-\(language)", languageId: language, source: "bundled",
                                               rulesSource: snapshot.origin, extensions: VSCodeBuiltInRules.extensions[language] ?? [],
                                               tags: EditorProfile.tagLanguages.contains(language))
        }
        for definition in VSCodeLanguages.definitions(roots: roots) {
            let known = byLanguage[definition.id]
            byLanguage[definition.id] = ProfileInfo(name: "vscode-\(definition.id)", languageId: definition.id, source: "installed",
                                                    rulesSource: definition.configuration.path,
                                                    extensions: definition.extensions.isEmpty ? (known?.extensions ?? []) : definition.extensions,
                                                    tags: EditorProfile.tagLanguages.contains(definition.id))
        }
        var profiles = byLanguage.values.sorted { $0.languageId < $1.languageId }
        let plain = EditorProfile.plainProfile
        profiles.insert(ProfileInfo(name: plain.name, languageId: "", source: "built-in", rulesSource: plain.rulesSource, extensions: [], tags: false), at: 0)
        let installed = profiles.filter { $0.source == "installed" }.count
        var response = ControlResponse(message: "\(profiles.count) profiles: plain, \(installed) from the installed VS Code and its extensions, \(BuiltInRules.snapshots.count) bundled from VS Code \(VSCodeBuiltInRules.version) and available without it.")
        response.profiles = profiles
        return response
    }
}
