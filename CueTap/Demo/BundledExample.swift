import Foundation

extension DemoScript {
    static let bundledExampleName = "html-demo.json"

    /// The same bytes as the html-demo.json copied next to the executable, kept in source so an
    /// installed copy still starts when that file is missing, unreadable or left behind by an installer.
    static let bundledExampleJSON = #"""
    {
      "version": 2,
      "name": "HTML Demo",
      "description": "Three independent HTML insertions: hello, world, and cuetap. Use the advance click between positions or files.",
      "segments": [
        {
          "name": "Segment 1: hello",
          "description": "The original HTML insertion sequence, ending with hello. Position the cursor manually.",
          "actions": [
            { "type": "text", "value": "<div></div>" },
            { "type": "key", "key": "left", "count": 7 },
            { "type": "text", "value": " class:\"body\"" },
            { "type": "key", "key": "right" },
            { "type": "key", "key": "enter" },
            { "type": "text", "value": "hello" }
          ]
        },
        {
          "name": "Segment 2: world",
          "description": "The original HTML insertion sequence, ending with world. Position the cursor manually.",
          "actions": [
            { "type": "text", "value": "<div></div>" },
            { "type": "key", "key": "left", "count": 7 },
            { "type": "text", "value": " class:\"body\"" },
            { "type": "key", "key": "right" },
            { "type": "key", "key": "enter" },
            { "type": "text", "value": "world" }
          ]
        },
        {
          "name": "Segment 3: cuetap",
          "description": "The original HTML insertion sequence, ending with cuetap. Position the cursor manually.",
          "actions": [
            { "type": "text", "value": "<div></div>" },
            { "type": "key", "key": "left", "count": 7 },
            { "type": "text", "value": " class:\"body\"" },
            { "type": "key", "key": "right" },
            { "type": "key", "key": "enter" },
            { "type": "text", "value": "cuetap" }
          ]
        }
      ]
    }
    """#

    /// Where an installed copy keeps its example. Homebrew links bin/cuetap to a versioned Cellar
    /// directory, so the link's own directory and the resolved one are both candidates; every caller
    /// must ask here so diagnostics and startup never disagree about which file they mean.
    static func bundledExampleURL(besideExecutable executable: URL) -> URL {
        let resolved = executable.resolvingSymlinksInPath().deletingLastPathComponent()
        let literal = executable.deletingLastPathComponent()
        for directory in [resolved, literal] {
            let url = directory.appendingPathComponent(bundledExampleName)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return resolved.appendingPathComponent(bundledExampleName)
    }

    /// Read the example, falling back to the compiled-in copy when the file is absent.
    static func readBundledExample(at url: URL) throws -> (file: File, isBuiltIn: Bool) {
        if FileManager.default.fileExists(atPath: url.path) { return (try readFile(from: url), false) }
        let data = Data(bundledExampleJSON.utf8)
        return (File(data: data, script: try decode(data)), true)
    }
}
