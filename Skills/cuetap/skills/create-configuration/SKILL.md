---
name: cuetap-create-configuration
description: Turn user-supplied text into a CueTap configuration with cuetap compile, then arrange an actual editor test checked with cuetap diff.
---

# Create or change a configuration

Follow the [root Skill](../../SKILL.md) shared rules. Read the [configuration format](../../references/configuration.md) for the schema the compiler writes, [typing order](../../references/typing-order.md) for what the compiler does with pairs, blocks and indentation, and [editor setup](../../references/editor-setup.md) for the editor settings a demo requires.

## Prepare the target text

Use the supplied text and editing process. The text can be anything typed by hand: source code, prose, commands, form input. If only the finished text is supplied, state the assumption of sequential typing from the beginning. Ask about cursor movements only when a requested insertion order is ambiguous. Do not invent a writing process the user did not describe.

Tell the user about any difference between what they supplied and what the configuration will type, before compiling. The common case is characters CueTap cannot send: only the 95 printable ASCII characters, newline and indentation tabs can be typed, so text in any other script, and punctuation like full-width colons and commas, has to be replaced or left out. `cuetap compile` refuses such text and lists every position; say which characters are affected and what you propose, and let the user choose. Do not translate, transliterate, drop or silently substitute anything they wrote. The same applies to a structural change, such as splitting one passage into segments or reordering an insertion: explain it and get agreement.

Write each insertion position as its own target text file, exactly as it should appear in the editor, with the target's real indentation. Save these files outside the configurations directory, for example next to the user's project or in a temporary folder, and keep them: `cuetap diff` compares against them after the demo.

## Compile

```sh
cuetap compile --profile vscode-c --output /absolute/path/demo.json --name "Name" --description "Description" /absolute/path/target.c --json
```

`--profile vscode-<language id>` names the editor and language, for any language VS Code or an installed extension defines: `vscode-c`, `vscode-python`, `vscode-html`, `vscode-vue`, `vscode-typescriptreact`, `vscode-go` and so on. The compiler finds the language's configuration the way VS Code does, through the extensions' package.json files under the application and `~/.vscode/extensions`, and falls back to a bundled snapshot for c, cpp, python, html and vue; the response says which source was used. An unknown id means the extension that provides it is not installed. For another editor pass `--rules FILE` with a file in the same shape as VS Code's language-configuration.json. `--tab-size N` and `--tabs` describe the editor's indentation settings when they are not four spaces. Tag pairing switches on by itself for the HTML family and `--tags` or `--no-tags` overrides it. Each target file becomes one segment named after the file; use one target per insertion position. `--output` refuses to replace an existing file unless `--force` is given.

Write `--name` and `--description` in the user's language. Describe the supplied project, page or module, and the passage itself, without inventing context.

The compiler validates the schema, replays the keystrokes through its model of the editor, and only writes the file when the replay reproduces the target. A `compile_failed` error means the model could not produce the target with the keys CueTap has; report it as such rather than editing the JSON by hand. `unsupported_character` and `unsupported_tab` point at the target text. Never hand-edit actions in a compiled file; change the target text or the profile and compile again. Renaming a configuration or changing only its description does not change the action sequence.

For VS Code profiles the response also carries `settings`: the user's settings.json checked against what the demo depends on. Report every `warning` to the user before the test and ask them to fix it; an `info` entry is a recommendation. The check reads the user file and the nearest `.vscode/settings.json` above the target files, workspace values winning; `settingsFile` lists what was read. A setting changed in the editor but not saved is not seen; [editor setup](../../references/editor-setup.md) remains the list to confirm with the user.

## Save and select

Write the compiled JSON into the user's CueTap configurations directory with a new filename, or compile straight to a new path there; the native menu discovers files when expanded or reopened. Do not overwrite another configuration merely because its display name matches. See [configuration management](../manage-configurations/SKILL.md) for paths and selection. For Agent-driven selection, use `config use ID` while the resident is off. Start the resident if the requested task requires it and it is absent. After recompiling the selected file in place, use `reload` while off. Report the absolute saved path.

## Test in the editor and check the result

A new or changed configuration needs an actual test in the intended editor before being reported as ready for reuse. Confirm the editor settings in [editor setup](../../references/editor-setup.md) are applied first; a sequence tested against a differently configured editor proves nothing. The user opens an empty scratch file in the editor, positions the cursor, activates the hotkey, presses physical keys, and deactivates the hotkey. Between segments, ordinary clicks navigate without advancing; the configured advance click (default Command + left click) positions and arms the next segment. Do not inject keys on the user's behalf.

When the demo has finished, ask the user to save the scratch file and compare it with the target text:

```sh
cuetap diff /absolute/path/target.c /absolute/path/scratch.c --json
```

An identical result is the test passing. A `text_mismatch` reports the first differing line and column with both lines. Read it against the target: a difference in indentation or an extra closing bracket means the editor did not behave as its profile predicts, so check the editor settings first and then the profile; a difference in characters means the target text or the user's typing went wrong. Fix the cause, compile again and repeat the test. Report whether this manual test has actually happened; do not claim an unperformed editor test passed.

Once the unchanged configuration has passed its test, reuse it directly.
