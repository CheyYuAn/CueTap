# Editor setup

CueTap sends one keystroke per action and nothing else. Any editor feature that inserts characters on its own collides with the configured actions, because the configuration already types those characters. Any feature that only moves the cursor, automatic indentation above all, must stay on, because configurations depend on it.

Before the first demo in a given editor, tell the user which settings to apply and ask them to confirm they are in place. Say plainly that the demo cannot be used without them: the failure shows up as duplicated brackets or collapsing indentation halfway through a recording. Do not start a demo on the assumption that an editor is already set up. For VS Code, `cuetap compile` reads the user's settings.json and the nearest workspace settings and reports these keys as `settings` findings; a `warning` there is the same request, already verified, and a setting it could not read still has to be confirmed by the user.

Only VS Code is supported among code editors: the `vscode-` profiles describe its indentation behaviour and the settings below are VS Code's. The `plain` profile covers fields with no editor behaviour at all, such as a terminal, a browser form or a notes app; there the only thing to confirm is that nothing autocompletes or auto-pairs.

## Turn off everything that types on the user's behalf

These are VS Code user settings, in `~/Library/Application Support/Code/User/settings.json`:

```json
"html.autoClosingTags": false,
"javascript.autoClosingTags": false,
"typescript.autoClosingTags": false,
"editor.autoClosingBrackets": "never",
"editor.autoClosingQuotes": "never",
"editor.acceptSuggestionOnEnter": "off",
"editor.acceptSuggestionOnCommitCharacter": false,
"editor.formatOnType": false,
"emmet.triggerExpansionOnTab": false
```

The three `autoClosingTags` entries stop the editor from completing a closing tag when the opening tag's `>` is typed; configurations type both halves of a tag themselves.

`autoClosingBrackets` and `autoClosingQuotes` stop the editor from inserting the right half of a pair. A configuration types the left symbol, then the right symbol, then moves the cursor back between them, which is what a person does on a keyboard. When the editor supplies the right half, the first keystroke puts both symbols on screen at once and the second merely steps over what is already there.

`acceptSuggestionOnEnter` matters because configurations press Enter on almost every line and the suggestion list is usually open on the word just typed. Left on, that Enter accepts a suggestion instead of breaking the line, and every line after it lands in the wrong place. `acceptSuggestionOnCommitCharacter` is the same risk for punctuation. `formatOnType` would rewrite lines the configuration has already typed. `emmet.triggerExpansionOnTab` matters where configurations send Tab inside HTML-like files, where Emmet expands the preceding word instead of indenting.

The compiler also checks `editor.tabSize`, `editor.insertSpaces` and `editor.autoIndent` against the profile, including any `[language]` blocks; an unset tab size means 4.

## Leave automatic indentation alone

Never ask the user to turn off `editor.autoIndent`, and never work around indentation by having the configuration type spaces. Editors indent on their own and configurations are compiled to rely on that: they type no leading whitespace and press Tab or Backspace at the start of a line only where the editor's own rules would land somewhere else. Typing explicit spaces on top of automatic indentation stacks the two into a staircase that grows deeper line by line. Setting `editor.autoIndent` to `none` under a `"[python]"` block does not even take effect, so that particular attempt produces the staircase while looking like it should not.

Indentation rules are per language and not symmetric. VS Code's Python rules indent one level after a line ending in a colon and have no rule for moving back out, which is why `elif` and `else` get a Backspace. [Typing order](typing-order.md) explains how the compiler handles this.
