import Foundation

/// An editor plus language, with the indentation settings the compiler assumes.
struct EditorProfile {
    let name: String
    let rules: EditorRules
    let rulesSource: String
    var tabSize = 4
    var insertSpaces = true
    var tags = false
    var languageId: String?
    /// Rules for the content of script and style elements, keyed by element name.
    var embedded: [String: EditorRules] = [:]
    /// A plain text field: Enter starts an unindented line, nothing closes pairs, and the target's
    /// indentation is typed as characters. Terminals, browser fields and note apps behave this way.
    var plain = false

    static let plainName = "plain"
    static var plainProfile: EditorProfile {
        // Brackets and double quotes still read as pairs when typed; single quotes are left alone
        // because prose is full of apostrophes that would pair up across a sentence.
        let rules = #"{"brackets":[["{","}"],["[","]"],["(",")"]],"autoClosingPairs":[{"open":"\"","close":"\""}]}"#
        var profile = EditorProfile(name: plainName, rules: try! EditorRules.parse(Data(rules.utf8)),
                                    rulesSource: "none: a plain text field that neither indents nor closes pairs", tabSize: 4, insertSpaces: true, tags: false, languageId: nil)
        profile.plain = true
        return profile
    }

    /// VS Code language ids whose documents are built from paired tags.
    static let tagLanguages: Set<String> = ["html", "vue", "xml", "xsl", "svelte", "astro", "javascriptreact", "typescriptreact", "jsx-tags", "handlebars", "razor", "php", "erb", "ejs", "twig", "blade"]
    static let exampleNames = ["vscode-c", "vscode-python", "vscode-html", "vscode-vue", "vscode-typescriptreact", "plain"]

    /// Resolve `vscode-<language id>` from the installed VS Code and its extensions when they are
    /// present, otherwise from the bundled snapshot of every language VS Code defines, or load an
    /// explicit rules file which needs no name. `roots` replaces the VS Code extension folders
    /// searched, and an empty list means no installation at all.
    static func resolve(name: String?, rulesPath: String?, tabSize: Int, insertSpaces: Bool, tags: Bool?, roots: [URL]? = nil) throws -> EditorProfile {
        if let rulesPath {
            let url = URL(fileURLWithPath: (rulesPath as NSString).expandingTildeInPath).standardizedFileURL
            return EditorProfile(name: name ?? "custom", rules: try EditorRules.load(from: url), rulesSource: url.path,
                                 tabSize: tabSize, insertSpaces: insertSpaces, tags: tags ?? false, languageId: nil)
        }
        if name == plainName {
            var profile = plainProfile
            profile.tabSize = tabSize; profile.insertSpaces = insertSpaces; profile.tags = tags ?? false
            return profile
        }
        guard let name, name.hasPrefix("vscode-"), name.count > "vscode-".count else {
            throw ControlError("profile_not_found", "Unknown profile \(name ?? "(none)"). Use vscode-<language id> for any language VS Code or one of its extensions defines, plain for a text field without editor behaviour, for example \(exampleNames.joined(separator: ", ")), or --rules FILE for another editor.")
        }
        let languageId = String(name.dropFirst("vscode-".count))
        let useTags = tags ?? tagLanguages.contains(languageId)
        guard var (rules, source) = try lookUpRules(for: languageId, roots: roots) else {
            throw ControlError("profile_not_found", "No language \(languageId) is defined by the installed VS Code or the extensions in ~/.vscode/extensions, and it is not one of the \(VSCodeBuiltInRules.languages.count) languages bundled from VS Code \(VSCodeBuiltInRules.version). Install the extension that provides it, or pass --rules FILE.")
        }
        if ["javascriptreact", "typescriptreact"].contains(languageId), let (tagRules, tagSource) = try lookUpRules(for: "jsx-tags", roots: roots) {
            rules = rules.merging(tagRules: tagRules)
            source += " with " + tagSource
        }
        var profile = EditorProfile(name: name, rules: rules, rulesSource: source, tabSize: tabSize, insertSpaces: insertSpaces, tags: useTags, languageId: languageId)
        if useTags { profile.embedded = embeddedRules(roots: roots) }
        return profile
    }

    /// A language's rules from the installed VS Code first, then from the bundled snapshot.
    static func lookUpRules(for languageId: String, roots: [URL]?) throws -> (EditorRules, String)? {
        if let url = VSCodeLanguages.configurationURL(for: languageId, roots: roots) {
            return (try EditorRules.load(from: url), url.path)
        }
        guard let snapshot = BuiltInRules.snapshots[languageId] else { return nil }
        do { return (try EditorRules.parse(Data(snapshot.json.utf8)), "built-in snapshot of \(snapshot.origin)") }
        catch { throw ControlError("rules_unreadable", "Built-in rules for vscode-\(languageId): \(error)") }
    }
}

extension EditorProfile {
    /// JavaScript rules for script elements and CSS rules for style elements.
    static func embeddedRules(roots: [URL]? = nil) -> [String: EditorRules] {
        var result: [String: EditorRules] = [:]
        for (element, language) in [("script", "javascript"), ("style", "css")] {
            if let (rules, _) = try? lookUpRules(for: language, roots: roots) { result[element] = rules }
        }
        return result
    }
}
