import Foundation

/// Tells code apart from strings and comments in the target text, pairs brackets and quotes, and in
/// tag languages pairs opening tags with their closing tags. Brackets inside a comment are typed as
/// plain characters.
struct SourceLexer {
    enum Region { case code, string, comment }

    let lineComment: String?
    let blockComment: (start: String, end: String)?
    let quotes: [Character]
    let brackets: [(open: Character, close: Character)]
    let tags: Bool
    /// Rules used to lex the content of script and style elements.
    let embedded: [String: EditorRules]

    /// Elements that never take a closing tag, from VS Code's HTML rules.
    static let voidElements: Set<String> = ["area", "base", "br", "col", "embed", "hr", "img", "input", "keygen", "link", "menuitem", "meta", "param", "source", "track", "wbr"]

    init(rules: EditorRules, tags: Bool, embedded: [String: EditorRules] = [:]) {
        lineComment = rules.lineComment
        blockComment = rules.blockComment
        quotes = rules.quotes
        self.tags = tags
        self.embedded = embedded
        brackets = rules.brackets.compactMap { pair in
            guard pair.open.count == 1, pair.close.count == 1, let open = pair.open.first, let close = pair.close.first else { return nil }
            if tags, open == "<" { return nil }
            return (open, close)
        }
    }

    /// An element whose opening and closing tags both appear in the target.
    struct TagPair {
        /// Index of the first character after the tag name inside the opening tag.
        let attributesStart: Int
        /// Index of the opening tag's closing angle bracket.
        let openEnd: Int
        let closeStart: Int
        let closeEnd: Int
    }

    struct Analysis {
        let regions: [Region]
        /// Opening index to closing index for every bracket and every single-line string that closes.
        let closerOf: [Int: Int]
        /// Closing index to opening index.
        let openerOf: [Int: Int]
        /// Opening tag start to its element, for tags that pair.
        let openingTags: [Int: TagPair]
        /// Closing tag start to the index of its final angle bracket.
        let closingTags: [Int: Int]
    }

    /// What script and style content looks like when VS Code's own rules for it are not at hand.
    static func defaultEmbeddedRules(for element: String) -> EditorRules {
        let json = element == "script"
            ? #"{"comments":{"lineComment":"//","blockComment":["/*","*/"]},"brackets":[["{","}"],["[","]"],["(",")"]],"autoClosingPairs":[{"open":"'","close":"'"},{"open":"\"","close":"\""},{"open":"`","close":"`"}]}"#
            : #"{"comments":{"blockComment":["/*","*/"]},"brackets":[["{","}"],["[","]"],["(",")"]],"autoClosingPairs":[{"open":"'","close":"'"},{"open":"\"","close":"\""}]}"#
        return try! EditorRules.parse(Data(json.utf8))
    }

    func analyze(_ characters: [Character]) -> Analysis {
        var regions = [Region](repeating: .code, count: characters.count)
        var closerOf: [Int: Int] = [:]
        var openerOf: [Int: Int] = [:]
        var openingTags: [Int: TagPair] = [:]
        var closingTags: [Int: Int] = [:]
        var index = 0
        func starts(with token: String, at position: Int) -> Bool {
            let tokenCharacters = Array(token)
            guard position + tokenCharacters.count <= characters.count else { return false }
            return Array(characters[position..<position + tokenCharacters.count]) == tokenCharacters
        }
        func isNameCharacter(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "-" || character == "_" || character == ":" || character == "."
        }
        func lexString(from start: Int, limit: Int) -> Int? {
            let quote = characters[start]
            var scan = start + 1
            while scan < limit, characters[scan] != "\n" {
                if characters[scan] == "\\", scan + 1 < limit, characters[scan + 1] != "\n" { scan += 2; continue }
                if characters[scan] == quote { return scan }
                scan += 1
            }
            return nil
        }
        var openTags: [(name: String, start: Int, attributesStart: Int, openEnd: Int)] = []
        var embeddedRanges: [Range<Int>] = []
        while index < characters.count {
            if let block = blockComment, !block.start.isEmpty, starts(with: block.start, at: index) {
                let start = index
                index += block.start.count
                while index < characters.count, !starts(with: block.end, at: index) { index += 1 }
                index = min(index + block.end.count, characters.count)
                for position in start..<index { regions[position] = .comment }
                continue
            }
            if let line = lineComment, !line.isEmpty, starts(with: line, at: index) {
                let start = index
                while index < characters.count, characters[index] != "\n" { index += 1 }
                for position in start..<index { regions[position] = .comment }
                continue
            }
            let character = characters[index]
            if tags, character == "<", index + 1 < characters.count {
                var cursor = index + 1
                let closing = characters[cursor] == "/"
                if closing { cursor += 1 }
                let nameStart = cursor
                if cursor < characters.count, characters[cursor].isLetter {
                    while cursor < characters.count, isNameCharacter(characters[cursor]) { cursor += 1 }
                    let name = String(characters[nameStart..<cursor]).lowercased()
                    let attributesStart = cursor
                    // Attributes end at the first > outside quotes and outside braces, so a JSX
                    // expression like onClick={() => f()} stays inside the tag; attributes may span
                    // lines, and another < before the > means this was not a tag.
                    var quote: Character?
                    var braces = 0
                    var end: Int?
                    while cursor < characters.count {
                        let current = characters[cursor]
                        if let open = quote { if current == open { quote = nil } }
                        else if current == "\"" || current == "'" { quote = current }
                        else if current == "{" { braces += 1 }
                        else if current == "}" { braces = max(braces - 1, 0) }
                        else if current == "<" { break }
                        else if current == ">", braces == 0 { end = cursor; break }
                        cursor += 1
                    }
                    if let end {
                        let selfClosing = end > nameStart && characters[end - 1] == "/"
                        if closing {
                            if let top = openTags.last, top.name == name {
                                openTags.removeLast()
                                openingTags[top.start] = TagPair(attributesStart: top.attributesStart, openEnd: top.openEnd, closeStart: index, closeEnd: end)
                                closingTags[index] = end
                            }
                        } else if !selfClosing, !Self.voidElements.contains(name) {
                            openTags.append((name, index, attributesStart, end))
                        }
                        // Attribute values are strings; the quotes pair like any other string.
                        var position = attributesStart
                        while position < end {
                            if characters[position] == "\"" || characters[position] == "'", let close = lexString(from: position, limit: end) {
                                for inner in position...close { regions[inner] = .string }
                                closerOf[position] = close
                                openerOf[close] = position
                                position = close + 1
                                continue
                            }
                            position += 1
                        }
                        index = end + 1
                        // Script and style content follows its own language: no tags inside, and
                        // its comments and strings as that language writes them.
                        if !closing, !selfClosing, name == "script" || name == "style" {
                            let closeToken = Array("</" + name)
                            var scan = index
                            var closeStart: Int?
                            while scan + closeToken.count <= characters.count {
                                if characters[scan..<scan + closeToken.count].map({ Character($0.lowercased()) }) == closeToken { closeStart = scan; break }
                                scan += 1
                            }
                            if let closeStart, closeStart > index {
                                let inner = SourceLexer(rules: embedded[name] ?? Self.defaultEmbeddedRules(for: name), tags: false)
                                    .analyze(Array(characters[index..<closeStart]))
                                for (offset, region) in inner.regions.enumerated() { regions[index + offset] = region }
                                for (open, close) in inner.closerOf { closerOf[index + open] = index + close; openerOf[index + close] = index + open }
                                embeddedRanges.append(index..<closeStart)
                                index = closeStart
                            }
                        }
                        continue
                    }
                }
                index += 1
                continue
            }
            if quotes.contains(character) {
                if let close = lexString(from: index, limit: characters.count) {
                    for position in index...close { regions[position] = .string }
                    closerOf[index] = close
                    openerOf[close] = index
                    index = close + 1
                } else {
                    // An unterminated quote is typed as it stands, and the rest of its line stays code.
                    index += 1
                }
                continue
            }
            index += 1
        }
        // Brackets pair across all of the code, skipping strings and comments, and separately inside
        // each string, so an f-string placeholder or a bracketed phrase inside a string is still typed
        // as a pair while a lone bracket in a string never pairs with code outside it.
        func pair(_ indices: [Int]) {
            var stack: [(close: Character, index: Int)] = []
            for index in indices {
                let character = characters[index]
                if let bracket = brackets.first(where: { $0.open == character }) {
                    stack.append((bracket.close, index))
                } else if brackets.contains(where: { $0.close == character }), let top = stack.last, top.close == character {
                    stack.removeLast()
                    closerOf[top.index] = index
                    openerOf[index] = top.index
                }
            }
        }
        pair(characters.indices.filter { position in regions[position] == .code && !embeddedRanges.contains { $0.contains(position) } })
        for (start, end) in closerOf where regions[start] == .string && end > start + 1 { pair(Array((start + 1)..<end)) }
        return Analysis(regions: regions, closerOf: closerOf, openerOf: openerOf, openingTags: openingTags, closingTags: closingTags)
    }
}
