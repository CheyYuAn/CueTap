# Editor setup

CueTap sends one keystroke per action and nothing else. Any editor feature that inserts characters on its own collides with the configured actions, because the configuration already types those characters. Any feature that only moves the cursor, automatic indentation above all, must stay on, because configurations depend on it.

Before the first demo in a given editor, tell the user which settings to apply and ask them to confirm the settings are in place. Say plainly that the demo cannot be used without them: a configuration that was tested elsewhere will produce broken text, and the failure shows up as duplicated brackets or collapsing indentation halfway through a recording. Do not start a demo on the assumption that an editor is already set up.

## Turn off everything that types on the user's behalf

These are VS Code user settings, in `~/Library/Application Support/Code/User/settings.json`:

```json
"html.autoClosingTags": false,
"javascript.autoClosingTags": false,
"typescript.autoClosingTags": false,
"editor.autoClosingBrackets": "never",
"editor.autoClosingQuotes": "never",
"editor.acceptSuggestionOnEnter": "off",
"emmet.triggerExpansionOnTab": false
```

The three `autoClosingTags` entries stop the editor from completing a closing tag when the opening tag's `>` is typed. Configurations type both halves of a tag themselves, so a completed tag arrives twice.

`autoClosingBrackets` and `autoClosingQuotes` stop the editor from inserting the right half of a pair. A configuration types the left symbol, then the right symbol, then moves the cursor back between them, which is what a person does on a keyboard. When the editor supplies the right half, the first keystroke puts both symbols on screen at once and the second keystroke merely steps over what is already there, so three keystrokes look like two and the demo stops reading as typing.

`acceptSuggestionOnEnter` matters because configurations press Enter on almost every line and the suggestion list is usually open on the word just typed. Left on, that Enter accepts a suggestion instead of breaking the line, and every line after it lands in the wrong place.

`emmet.triggerExpansionOnTab` affects configurations that send Tab inside HTML-like files, where Emmet expands the preceding word instead of indenting.

Other editors have their own names for these. The rule to carry over is that nothing may type on the user's behalf.

## Leave automatic indentation alone

Never ask the user to turn off `editor.autoIndent`, and never work around indentation by having the configuration type spaces. Editors indent correctly on their own and configurations are written to rely on that, so the only indentation action a configuration needs is a Backspace where a line has to move back out one level. Typing explicit spaces on top of automatic indentation stacks the two, and the result is a staircase that grows deeper line by line. Setting `editor.autoIndent` to `none` under a `"[python]"` language block does not even take effect, so that particular attempt produces the staircase while looking like it should not.

Indentation behaviour comes from each language's configuration, and it is not symmetric. VS Code's built-in Python rules, for example, indent one level after a line ending in a colon and have no rule at all for moving back out, which is why `elif` and `else` need an explicit Backspace. Read [typing order](typing-order.md) for how that fits into a sequence.
