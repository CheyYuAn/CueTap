---
name: cuetap-create-configuration
description: Prepare or edit CueTap action JSON from user-supplied code and an editing sequence, then validate and arrange an actual editor test.
---

# Create or change an action sequence

Follow the [root Skill](../../SKILL.md) shared rules. Read the [configuration format](../../references/configuration.md) before writing JSON; it owns the schema, supported characters, limits, and example.

## Prepare the sequence

Use the supplied code and editing process. If only final code is supplied, state the assumption of sequential typing from the beginning. Ask about cursor movements only when a requested insertion order is ambiguous. Do not invent a programmer's writing process.

Include a useful `name` and `description` in the user's language. Describe the supplied project, page/module, and code section without inventing context. Preserve intentional syntax and explicit whitespace. Explain unsupported characters or actions rather than silently translating, dropping, or replacing code.

For multiple insertion positions or files, create ordered version 2 segments with separate names, descriptions, and actions. The user positions each segment manually; do not encode mouse navigation or infer file coordinates.

Save a local draft and validate the new or changed sequence:

```sh
cuetap validate /absolute/path/demo.json --json
```

Validation is read-only and does not import the file, create user data, or intercept input. Omitting FILE checks the bundled example, not the selected configuration. For `invalid_script`, fix the reported field in the draft rather than unrelated configurations.

## Save and test

Save the validated JSON into the user's CueTap configurations directory with a new filename, using an atomic write so a partial document is not listed. Do not overwrite another configuration merely because its display name matches. The native menu discovers files when expanded or reopened; no import command is required. See [configuration management](../manage-configurations/SKILL.md) for paths and selection.

For Agent-driven selection, use `config use ID` while the resident is off. Start the resident if the requested task requires it and it is absent. Existing `load` and `start --script` remain available for importing external sources. After editing the selected file, use `reload` or select it again while off. Report the absolute saved path.

A new or changed action sequence needs an actual test in the intended editor before being reported as ready for reuse. The user prepares editor behavior and the starting cursor, activates the hotkey, presses physical keys, checks the result, and deactivates the hotkey. Between segments, ordinary clicks navigate without advancing; the configured advance click (default Command + left click) positions and arms the next segment. Release mouse and modifiers before typing. Structural validation alone does not establish the typing order or editor result. Report whether this manual test has actually happened; do not inject keys on the user's behalf.

Once the unchanged configuration has passed its test, reuse it directly. Renaming a configuration or changing only its description does not change the action sequence and does not require repeating its typing test.
