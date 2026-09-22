/// Snapshots of language configurations the compiler falls back to when the installed VS Code or the
/// extension that provides the language cannot be found, so a machine without them still compiles every
/// language VS Code defines; the compile report says which source was used. Each is the file as shipped,
/// kept byte for byte.
enum BuiltInRules {
    struct Snapshot {
        let origin: String
        let json: String
    }

    /// Every language VS Code itself defines, from the generated VSCodeBuiltInRules, plus the Vue
    /// extension's rules, which VS Code does not ship.
    static let snapshots: [String: Snapshot] = {
        var result: [String: Snapshot] = [:]
        for (language, path) in VSCodeBuiltInRules.languages {
            guard let json = VSCodeBuiltInRules.files[path] else { continue }
            result[language] = Snapshot(origin: "VS Code \(VSCodeBuiltInRules.version) extensions/\(path)", json: json)
        }
        result["vue"] = Snapshot(origin: "Vue extension 3.3.11 languages/vue-language-configuration.json", json: vue)
        return result
    }()

    static var cpp: String { snapshots["cpp"]!.json }
    static var python: String { snapshots["python"]!.json }
    static var html: String { snapshots["html"]!.json }

    /// languages/vue-language-configuration.json, Vue extension (vue.volar) 3.3.11.
    static let vue = ##"""
    {
    	"comments": {
    		"blockComment": ["<!--", "-->"]
    	},
    	"brackets": [
    		// html
    		["<!--", "-->"],
    		["{", "}"],
    		["(", ")"]
    	],
    	"autoClosingPairs": [
    		// html
    		{ "open": "{", "close": "}" },
    		{ "open": "[", "close": "]" },
    		{ "open": "(", "close": ")" },
    		{ "open": "'", "close": "'" },
    		{ "open": "\"", "close": "\"" },
    		{ "open": "<!--", "close": "-->", "notIn": ["comment", "string"] },
    		// javascript
    		{ "open": "`", "close": "`", "notIn": ["string", "comment"] },
    		{ "open": "/**", "close": " */", "notIn": ["string"] }
    	],
    	// #1437
    	"autoCloseBefore": ";:.,=}])><`'\" \n\t",
    	"surroundingPairs": [
    		// html
    		{ "open": "'", "close": "'" },
    		{ "open": "\"", "close": "\"" },
    		{ "open": "{", "close": "}" },
    		{ "open": "[", "close": "]" },
    		{ "open": "(", "close": ")" },
    		{ "open": "<", "close": ">" },
    		// javascript
    		["`", "`"]
    	],
    	"colorizedBracketPairs": [],
    	"folding": {
    		"markers": {
    			"start": "^\\s*<!--\\s*#region\\b.*-->",
    			"end": "^\\s*<!--\\s*#endregion\\b.*-->"
    		}
    	},
    	"wordPattern": "(-?\\d*\\.\\d\\w*)|([^\\`\\~\\!\\@\\$\\^\\&\\*\\(\\)\\=\\+\\[\\{\\]\\}\\\\\\|\\;\\:\\'\\\"\\,\\.\\<\\>\\/\\s]+)",
    	"onEnterRules": [
    		{
    			"beforeText": {
    				"pattern": "<(?!(?:area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr|script|style))([_:\\w][_:\\w-.\\d]*)(?:(?:[^'\"/>]|\"[^\"]*\"|'[^']*')*?(?!\\/)>)[^<]*$",
    				"flags": "i"
    			},
    			"afterText": { "pattern": "^<\\/([_:\\w][_:\\w-.\\d]*)\\s*>", "flags": "i" },
    			"action": {
    				"indent": "indentOutdent"
    			}
    		},
    		{
    			"beforeText": {
    				"pattern": "<(?!(?:area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr|script|style))([_:\\w][_:\\w-.\\d]*)(?:(?:[^'\"/>]|\"[^\"]*\"|'[^']*')*?(?!\\/)>)[^<]*$",
    				"flags": "i"
    			},
    			"action": {
    				"indent": "indent"
    			}
    		}
    	],
    	"indentationRules": {
    		"increaseIndentPattern": "<(?!\\?|(?:area|base|br|col|frame|hr|html|img|input|keygen|link|menuitem|meta|param|source|track|wbr|script|style)\\b|[^>]*\\/>)([-_\\.A-Za-z0-9]+)(?=\\s|>)\\b[^>]*>(?!.*<\\/\\1>)|<!--(?!.*-->)|\\{[^}\"']*$",
    		"decreaseIndentPattern": "^\\s*(<\\/(?!html)[-_\\.A-Za-z0-9]+\\b[^>]*>|-->|\\})"
    	}
    }
    """##
}
