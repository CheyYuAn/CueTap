# Typing order

A configuration has to read as a person typing, not as a finished file being pasted one character at a time. The order is decided by `cuetap compile`, not by hand: it takes the target text and an editor profile, works out every keystroke, replays the result through a model of the editor, and refuses to write a configuration that would not reproduce the target. Do not write or edit action sequences by hand and do not simulate keystrokes yourself; the rules below describe what the compiler does so its output can be explained and its failures understood.

All of this assumes the editor is set up as [editor setup](editor-setup.md) describes, with nothing typing on the user's behalf.

## Paired symbols

Brackets, parentheses, quotes and braces are typed as two keystrokes and then a cursor move: the left symbol, the right symbol, then `left` once to land between them, and only then the content. When the content is finished, `right` steps back out over the closing symbol, once per layer. This holds in every language, and it holds inside strings too, so an f-string placeholder `{guesses}` is a pair, while a lone bracket inside a string or any bracket inside a comment is typed as a plain character. An empty pair such as `rand()` is typed straight through.

A nested call is the same rule applied repeatedly. To produce `int(input("Guess: "))`:

```
int  →  ()  →  left  →  input  →  ()  →  left  →  ""  →  left  →  Guess:   →  right × 3
```

Whenever a passage contains a paired symbol, it cannot go into a single text action; the compiler splits the text at every pair.

## Blocks that span lines

A brace block is opened as a pair as well: `{}`, `left`, then whatever belongs on the same line, then Enter. The editor decides what happens next, and the compiler follows it. When the brace is the last thing on its line, VS Code expands `{|}` into three lines with the closing brace on its own line below. When code follows the brace on the same line, as in `do { printf(...); n++;`, the closing brace is still after the cursor when Enter is pressed, and the C rules pull the new line back out by one level; the compiler notices that the target line is deeper and presses Tab once at the start of the new line.

The closing brace is never typed a second time. When the target reaches it, the compiler walks over it with `right`, counting the newline, the indentation and the brace itself, and continues with whatever follows, such as ` while (guess != secret);`. When the rest of the target is exactly what the editor already holds, typically the outermost closing brace on the last line, the sequence simply stops.

## Indentation

Configurations do not type indentation. The editor indents, and the compiler predicts what it will do from the language's own rules: for VS Code, the `brackets`, `indentationRules` and `onEnterRules` in the language configuration that ships with the editor. After every Enter it compares the predicted indentation with the target line's and corrects the difference with `tab` or `backspace`, pressed at the start of the line before any character. That is where Python's `elif` and `else` get their Backspace, because the Python rules only ever indent after a colon and never move back out.

Tab and Backspace appear only at line starts. A Tab after a typed word would accept the editor's completion instead of indenting.

## Tags

In tag languages the compiler writes every element as a pair before anything goes inside it, in three steps. First the bare tag name, closed immediately: `<button></button>`. Then, when the tag has attributes, `left` far enough to put the cursor inside the opening tag just before its `>`, where the class, inline style, event binding or JSX expression gets typed with the usual pair rules; then `right` once to step over that `>`. An element without attributes goes back only as far as the closing tag, so `<p></p>` is followed by `left` four times. The element's text or its nested children follow. A single-line leaf element steps over its whole closing tag with `right` before Enter starts the next line; a container presses Enter inside, the editor puts the closing tag on its own line below, and the compiler walks to it later or stops when nothing else remains.

An opening tag spread over several lines is still a pair: Enter inside the tag, then Tab or Backspace to the attribute line's depth, and `right` over the `>` once it is reached. Void elements such as `<br>` and `<img ...>`, self-closing tags, comments and unmatched closing tags are typed as plain text. Inside `<script>` and `<style>` the compiler switches to VS Code's JavaScript and CSS rules, so braces in a script block expand the way they do in a .js file. Tag pairing is on by default for the HTML family, which includes html, vue, xml, xsl, svelte, astro, javascriptreact, typescriptreact, handlebars, razor and php, and `--tags` or `--no-tags` overrides that for any profile. JSX and TSX use VS Code's own jsx-tags rules for Enter inside elements and the JavaScript or TypeScript rules everywhere else.

## When the result is wrong

The compiler's model of the editor comes from the editor's own rule file, so a real run that differs from the target means either the editor's settings are not the ones in [editor setup](editor-setup.md), or the editor does something its published rules do not say. Compare the played file with the target using `cuetap diff`; it reports the first differing line and column. Check the settings first. If they are right, the profile needs a correction for that editor and language, which fixes every configuration compiled with it.
