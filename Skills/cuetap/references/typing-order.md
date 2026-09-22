# Typing order

A configuration has to read as a person typing, not as a finished file pasted one character at a time. `cuetap compile` decides the order: it takes the target text and an editor profile, works out every keystroke, replays the result through a model of the editor, and refuses to write a configuration that would not reproduce the target. Do not write or edit action sequences by hand. This document says what the compiler produces, so its output can be explained to the user and a `diff` mismatch can be read.

All of it assumes the editor is set up as [editor setup](editor-setup.md) describes, with nothing typing on the user's behalf. With the `plain` profile there is no editor behaviour to follow: pairs are still typed as pairs, but Enter produces an unindented line and the compiler types the target's indentation as characters instead of pressing Tab or Backspace.

## Paired symbols

Brackets, parentheses, quotes and braces are typed as two keystrokes and a cursor move: left symbol, right symbol, `left` once to land between them, then the content; `right` steps back out over the closing symbol, once per layer. This holds inside strings too, so an f-string placeholder `{guesses}` is a pair, while a lone bracket in a string or any bracket in a comment is a plain character. An empty pair such as `rand()` is typed straight through. `int(input("Guess: "))` becomes:

```
int  →  ()  →  left  →  input  →  ()  →  left  →  ""  →  left  →  Guess:   →  right × 3
```

## Blocks and indentation

A brace block is opened the same way: `{}`, `left`, whatever belongs on the same line, then Enter. The editor decides what happens next and the compiler follows its rules: VS Code expands `{|}` into three lines with the closing brace below, and when code follows the brace on the same line the C rules pull the new line back out, so the compiler presses Tab once at the start of that line. The closing brace is never typed twice; when the target reaches it, the compiler walks over it with `right` and continues, or simply stops when the rest of the target is exactly what the editor already holds.

Configurations type no indentation. After every Enter the compiler predicts the editor's indentation from the language's own rules and corrects the difference with Tab or Backspace at the start of the line, before any character. That is where Python's `elif` and `else` get their Backspace. Tab and Backspace never appear after a typed word, where Tab would accept a completion.

## Tags

In tag languages every element is written as a pair first: `<button></button>`, then `left` into the opening tag just before its `>` when it has attributes, the attributes with the usual pair rules, `right` over the `>`, then the content or children. A single-line element steps over its closing tag with `right` before the next Enter; a container presses Enter inside and the editor places the closing tag below. An opening tag spread over several lines gets Enter inside the tag and Tab or Backspace to the attribute lines' depth. Void elements such as `<br>` and `<img ...>`, self-closing tags, comments and unmatched closing tags are plain text. Inside `<script>` and `<style>` the compiler switches to the JavaScript and CSS rules. Tag pairing is on by default for the HTML family and `--tags` or `--no-tags` overrides it; JSX and TSX use VS Code's jsx-tags rules inside elements.

## Reading a diff mismatch

The compiler's model comes from the editor's own rule file, so a real run that differs from the target means one of three things, in order of likelihood: the editor's settings are not the ones in [editor setup](editor-setup.md), the demo was played in a different editor or language mode than the profile, or the editor does something its published rules do not say. `cuetap diff` reports the first differing line and column. Doubled brackets or tags point at auto-closing left on; a line indented one level off points at `tabSize`, `insertSpaces` or a language mode mismatch; a missing line break with the next line's text appended points at Enter accepting a suggestion; a difference in the characters themselves points at the target text. Check the settings first. Only when they are right does the profile need a correction for that editor and language, which fixes every configuration compiled with it.
