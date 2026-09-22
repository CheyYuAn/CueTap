# Create or change a configuration

Follow the [root Skill](../SKILL.md) shared rules. The flow is: write the target text to a file, pick the profile, compile, save and select, let the user play it, compare the result with `cuetap diff`.

## Prepare the target text

Use the supplied text and editing process. The text can be anything typed by hand: source code, prose, commands, form input. If only the finished text is supplied, state the assumption of sequential typing from the beginning. Ask about cursor movements only when a requested insertion order is ambiguous. Do not invent a writing process the user did not describe.

Tell the user, before compiling, about any difference between what they supplied and what the configuration will type. The common case is characters CueTap cannot send: only the 95 printable ASCII characters, newline and indentation tabs can be typed, so text in any other script, and punctuation like full-width colons and commas, has to be replaced or left out. `cuetap compile` refuses such text and lists every position; say which characters are affected and what you propose, and let the user choose. Do not translate, transliterate, drop or silently substitute anything they wrote. The same applies to a structural change, such as splitting one passage into segments or reordering an insertion: explain it and get agreement.

Write each insertion position as its own target text file, exactly as it should appear in the editor, with the target's real indentation. Save these files outside the configurations directory, for example next to the user's project or in a temporary folder, and keep them: `cuetap diff` compares against them after the demo.

## Pick the profile

A profile is `vscode-<language id>`, where the id is the one VS Code shows in its status bar for that file type: `vscode-c`, `vscode-python`, `vscode-html`, `vscode-vue`, `vscode-typescriptreact` for `.tsx`, `vscode-javascriptreact` for `.jsx`, `vscode-cpp` for `.cc` and `.hpp`, `vscode-markdown`, `vscode-shellscript`, `vscode-go`, `vscode-rust`, `vscode-dart`, `vscode-swift`. When the id is not obvious from the file name, list what this machine resolves:

```sh
cuetap profiles --json
```

Each entry has `name`, `languageId`, `source`, `rulesSource`, `extensions` and `tags`. Match the target's file extension against `extensions`. `source` is `built-in` for `plain`, `bundled` for the 70 languages VS Code itself defines, whose rules ship inside the executable, and `installed` for languages an installed VS Code or one of its extensions defines, which the compiler prefers when present. Compiling therefore does not need VS Code on the machine; only a language that solely a third-party extension provides, such as Vue on a machine without the Vue extension, falls outside the bundled set, and Vue is bundled too.

The other profile is `plain`: a text field with no editor behaviour, where Enter starts an unindented line and nothing closes pairs. Use it for anything typed outside a code editor: a terminal, a browser form or chat box, a notes app, a document editor without auto-indent. The compiler then types the target's indentation as characters and never presses Tab or Backspace, while pairs are still typed as pairs so the typing reads naturally. `plain` runs no settings check; confirm with the user that the field has no autocomplete or auto-pairing of its own.

Beyond these, only VS Code profiles exist. A `vscode-` profile encodes how VS Code indents on Enter and reacts to closing brackets, so a configuration compiled for `vscode-c` reproduces the target in VS Code and not necessarily in another code editor. `--rules FILE` accepts another editor's rules in VS Code's language-configuration.json shape but does not change that model; do not offer it as support for Xcode or JetBrains editors.

## Compile

```sh
cuetap compile --profile vscode-c --output /absolute/path/demo.json --name "Name" --description "Description" /absolute/path/target.c --json
```

Each target file becomes one segment named after the file, in argument order; use one target per insertion position. `--tab-size N` and `--tabs` describe the editor's indentation settings when they are not four spaces. Tag pairing switches on by itself for the HTML family (html, vue, xml, svelte, astro, jsx, tsx, php and others) and `--tags` or `--no-tags` overrides it. `--output` refuses to replace an existing file unless `--force` is given. Write `--name` and `--description` in the user's language, describing the project, page or module and the passage itself, without inventing context.

A successful response looks like this, abbreviated:

```json
{
  "ok": true,
  "outputPath": "/Users/me/Library/Application Support/CueTap/configurations/guess-number.json",
  "compile": {
    "profile": "vscode-c",
    "rulesSource": "/Applications/Visual Studio Code.app/Contents/Resources/app/extensions/cpp/language-configuration.json",
    "tabSize": 4, "insertSpaces": true, "tags": false, "actionCount": 371,
    "segments": [{ "name": "guess-number.c", "source": "/Users/me/demo/guess-number.c", "lines": 24, "actions": 371, "droppedTrailingNewline": true }],
    "settingsFile": "/Users/me/Library/Application Support/Code/User/settings.json",
    "settings": [
      { "severity": "warning", "key": "editor.autoClosingBrackets", "expected": "\"never\"", "actual": "\"languageDefined\"", "note": "The editor would insert the closing bracket the configuration is about to type." }
    ]
  }
}
```

The compiler validates the schema, replays the keystrokes through its model of the editor, and only writes the file when the replay reproduces the target. `compile_failed` means the model could not produce the target with the keys CueTap has; report it as such rather than editing the JSON by hand. `unsupported_character` and `unsupported_tab` point at the target text. `profile_not_found` means the language is neither bundled nor provided by an installed extension; ask the user to install the VS Code extension for it. Never hand-edit actions in a compiled file; change the target text or the options and compile again. Renaming a configuration or changing only its description does not change the action sequence.

Report every `warning` in `settings` to the user before the test and ask them to fix it; an `info` entry is a recommendation. The check reads the user settings file and the nearest `.vscode/settings.json` above the target files, workspace values winning; `settingsFile` lists what was read. A setting changed in the editor but not saved is not seen, and settings the check cannot read are confirmed from [editor setup](editor-setup.md).

## Save and select

Compile straight to a new path inside the user's configurations directory, or write the compiled JSON there with a new filename; the filename without `.json` becomes the configuration ID, and the native menu discovers files when expanded or reopened. Do not overwrite another configuration merely because its display name matches. Select it with `config use ID` while the resident is off, starting the resident first if the task needs it; after recompiling the selected file in place, use `reload`. Paths and commands are in [manage-configurations](manage-configurations.md). Report the absolute saved path.

## Test in the editor and check the result

A new or changed configuration needs an actual test in the intended editor before being reported as ready for reuse. The user opens an empty scratch file in the editor, positions the cursor, activates the hotkey, presses physical keys, and the demo ends by itself. Between segments, ordinary clicks navigate without advancing; the configured advance click (default Command + left click) positions and arms the next segment.

When the demo has finished, ask the user to save the scratch file and compare it with the target text, one expected/actual pair per segment when the demo spanned several files:

```sh
cuetap diff /absolute/path/target.c /absolute/path/scratch.c --json
cuetap diff /absolute/path/first.py /absolute/path/scratch-1.py /absolute/path/second.py /absolute/path/scratch-2.py --json
```

An identical result is the test passing. A `text_mismatch` reports, for each pair that differs, the first differing line and column with both lines. Read it against the target: a difference in indentation or an extra closing bracket means the editor did not behave as its profile predicts, so check the editor settings first; a difference in characters means the target text or the user's typing went wrong. [Typing order](typing-order.md) explains what the compiler expected the editor to do. Fix the cause, compile again and repeat the test. Report whether this manual test has actually happened; do not claim an unperformed editor test passed.

Once the unchanged configuration has passed its test, reuse it directly.
