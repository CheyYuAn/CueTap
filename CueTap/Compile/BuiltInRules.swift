/// Snapshots of language configurations the compiler can fall back to when the installed VS Code or the
/// extension that provides the language cannot be found, so a machine without them can still compile;
/// the compile report says which source was used. Each is the file as shipped, kept byte for byte.
enum BuiltInRules {
    struct Snapshot {
        let origin: String
        let json: String
    }

    static let snapshots: [String: Snapshot] = [
        "c": Snapshot(origin: "VS Code 1.138.0 extensions/cpp/language-configuration.json", json: cpp),
        "cpp": Snapshot(origin: "VS Code 1.138.0 extensions/cpp/language-configuration.json", json: cpp),
        "cuda-cpp": Snapshot(origin: "VS Code 1.138.0 extensions/cpp/language-configuration.json", json: cpp),
        "python": Snapshot(origin: "VS Code 1.138.0 extensions/python/language-configuration.json", json: python),
        "html": Snapshot(origin: "VS Code 1.138.0 extensions/html/language-configuration.json", json: html),
        "vue": Snapshot(origin: "Vue extension 3.3.11 languages/vue-language-configuration.json", json: vue),
    ]

    /// extensions/cpp/language-configuration.json, VS Code 1.138.0.
    static let cpp = ##"""
    {"comments":{"lineComment":"//","blockComment":["/*","*/"]},"brackets":[["{","}"],["[","]"],["(",")"]],"autoClosingPairs":[{"open":"[","close":"]"},{"open":"{","close":"}"},{"open":"(","close":")"},{"open":"'","close":"'","notIn":["string","comment"]},{"open":"\"","close":"\"","notIn":["string"]},{"open":"/*","close":"*/","notIn":["string","comment"]},{"open":"/**","close":" */","notIn":["string"]}],"surroundingPairs":[["{","}"],["[","]"],["(",")"],["\"","\""],["'","'"],["<",">"]],"wordPattern":"(-?\\d*\\.\\d\\w*)|([^\\`\\~\\!\\@\\#\\%\\^\\&\\*\\(\\)\\-\\=\\+\\[\\{\\]\\}\\\\\\|\\;\\:\\'\\\"\\,\\.\\<\\>\\/\\?\\s]+)","folding":{"markers":{"start":"^\\s*#\\s*pragma\\s+region\\b","end":"^\\s*#\\s*pragma\\s+endregion\\b"}},"indentationRules":{"decreaseIndentPattern":{"pattern":"^\\s*[\\}\\]\\)].*$"},"increaseIndentPattern":{"pattern":"^.*(\\{[^}]*|\\([^)]*|\\[[^\\]]*)$"}},"onEnterRules":[{"previousLineText":"^\\s*(((else ?)?if|for|while)\\s*\\(.*\\)\\s*|else\\s*)$","beforeText":"^\\s+([^{i\\s]|i(?!f\\b))","action":{"indent":"outdent"}},{"beforeText":"^\\s*//\\s*\\S|\\s//\\s+\\S","afterText":"^(?!\\s*$)","action":{"indent":"none","appendText":"// "}}]}
    """##

    /// extensions/python/language-configuration.json, VS Code 1.138.0.
    static let python = ##"""
    {"comments":{"lineComment":"#","blockComment":["\"\"\"","\"\"\""]},"brackets":[["{","}"],["[","]"],["(",")"]],"autoClosingPairs":[{"open":"{","close":"}"},{"open":"[","close":"]"},{"open":"(","close":")"},{"open":"\"","close":"\"","notIn":["string"]},{"open":"r\"","close":"\"","notIn":["string","comment"]},{"open":"R\"","close":"\"","notIn":["string","comment"]},{"open":"u\"","close":"\"","notIn":["string","comment"]},{"open":"U\"","close":"\"","notIn":["string","comment"]},{"open":"f\"","close":"\"","notIn":["string","comment"]},{"open":"F\"","close":"\"","notIn":["string","comment"]},{"open":"b\"","close":"\"","notIn":["string","comment"]},{"open":"B\"","close":"\"","notIn":["string","comment"]},{"open":"'","close":"'","notIn":["string","comment"]},{"open":"r'","close":"'","notIn":["string","comment"]},{"open":"R'","close":"'","notIn":["string","comment"]},{"open":"u'","close":"'","notIn":["string","comment"]},{"open":"U'","close":"'","notIn":["string","comment"]},{"open":"f'","close":"'","notIn":["string","comment"]},{"open":"F'","close":"'","notIn":["string","comment"]},{"open":"b'","close":"'","notIn":["string","comment"]},{"open":"B'","close":"'","notIn":["string","comment"]},{"open":"`","close":"`","notIn":["string"]}],"surroundingPairs":[["{","}"],["[","]"],["(",")"],["\"","\""],["'","'"],["`","`"]],"folding":{"offSide":true,"markers":{"start":"^\\s*#\\s*region\\b","end":"^\\s*#\\s*endregion\\b"}},"onEnterRules":[{"beforeText":"^\\s*(?:def|class|for|if|elif|else|while|try|with|finally|except|async).*?:\\s*$","action":{"indent":"indent"}}]}
    """##

    /// extensions/html/language-configuration.json, VS Code 1.138.0.
    static let html = ##"""
    {"comments":{"blockComment":["<!--","-->"]},"brackets":[["<!--","-->"],["{","}"],["(",")"]],"autoClosingPairs":[{"open":"{","close":"}"},{"open":"[","close":"]"},{"open":"(","close":")"},{"open":"'","close":"'"},{"open":"\"","close":"\""},{"open":"<!--","close":"-->","notIn":["comment","string"]}],"surroundingPairs":[{"open":"'","close":"'"},{"open":"\"","close":"\""},{"open":"{","close":"}"},{"open":"[","close":"]"},{"open":"(","close":")"},{"open":"<","close":">"}],"colorizedBracketPairs":[],"folding":{"markers":{"start":"^\\s*<!--\\s*#region\\b.*-->","end":"^\\s*<!--\\s*#endregion\\b.*-->"}},"wordPattern":"(-?\\d*\\.\\d\\w*)|([^\\`\\~\\!\\@\\$\\^\\&\\*\\(\\)\\=\\+\\[\\{\\]\\}\\\\\\|\\;\\:\\'\\\"\\,\\.\\<\\>\\/\\s]+)","onEnterRules":[{"beforeText":{"pattern":"<(?!(?:area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr))([_:\\w][_:\\w-.\\d]*)(?:(?:[^'\"/>]|\"[^\"]*\"|'[^']*')*?(?!\\/)>)[^<]*$","flags":"i"},"afterText":{"pattern":"^<\\/([_:\\w][_:\\w-.\\d]*)\\s*>","flags":"i"},"action":{"indent":"indentOutdent"}},{"beforeText":{"pattern":"<(?!(?:area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr))([_:\\w][_:\\w-.\\d]*)(?:(?:[^'\"/>]|\"[^\"]*\"|'[^']*')*?(?!\\/)>)[^<]*$","flags":"i"},"action":{"indent":"indent"}}],"indentationRules":{"increaseIndentPattern":"<(?!\\?|(?:area|base|br|col|frame|hr|html|img|input|keygen|link|menuitem|meta|param|source|track|wbr)\\b|[^>]*\\/>)([-_\\.A-Za-z0-9]+)(?=\\s|>)\\b[^>]*>(?!.*<\\/\\1>)|<!--(?!.*-->)|\\{[^}\"']*$","decreaseIndentPattern":"^\\s*(<\\/(?!html)[-_\\.A-Za-z0-9]+\\b[^>]*>|-->|\\})"}}
    """##

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
