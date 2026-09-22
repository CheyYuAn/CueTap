# Action configuration formats

Files are UTF-8 JSON. Use version 2 for ordered multi-segment demos. Version 1 remains supported as a single segment without rewriting existing files.
Configurations are produced by `cuetap compile` from target text files; see [create-configuration](../skills/create-configuration/SKILL.md). The schema below is what it writes and what hand-written files for tag languages must follow.

## Version 2

Allowed root fields: version (2), name (nonblank string), description (optional string), and segments (nonempty array). Root actions are not allowed. Each segment has a nonblank name, optional description, and a nonempty actions array. Array order defines segment order; there is no separate numeric ordering field.

```json
{
  "version": 2,
  "name": "Two positions",
  "description": "Two independent insertions, positioned manually.",
  "segments": [
    { "name": "First position", "description": "Insert hello.", "actions": [{ "type": "text", "value": "hello" }] },
    { "name": "Second position", "description": "Insert world.", "actions": [{ "type": "text", "value": "world" }] }
  ]
}
```

Names and descriptions support Unicode and the user's language. They describe intent and do not locate files, run commands, or move the cursor. Include useful descriptions in new configurations. Do not invent file names or project details. Missing descriptions default to empty strings.

## Version 1 compatibility

Allowed root fields: version (1), name, description, and actions. segments is not allowed. The name, description, and action rules match version 2.

```json
{
  "version": 1,
  "name": "HTML Demo",
  "description": "Single-position HTML demo: create a div pair, insert its class attribute, and type hello inside.",
  "actions": [
    { "type": "text", "value": "<div></div>" },
    { "type": "key", "key": "left", "count": 7 },
    { "type": "text", "value": " class:\"body\"" },
    { "type": "key", "key": "right" },
    { "type": "key", "key": "enter" },
    { "type": "text", "value": "hello" }
  ]
}
```

## Actions and limits

A text action accepts only type and a nonempty value. Text expands into individual characters when loaded; it is not pasted all at once. One fresh physical key-down executes one expanded action.
A key action accepts only type, key, and optional count. Supported keys are left/right/enter/tab/backspace. count is a positive integer, defaulting to 1. A count of 7 requires seven separate presses.
left and right move the cursor, which is how a sequence gets back inside a pair of symbols or a pair of tags and back out again. backspace is what moves a line out one indentation level, in editors that indent on their own but have no rule for dedenting.
Text supports the 95 printable ASCII characters. LF or CRLF becomes one Enter action; a tab character becomes one Tab action. Non-ASCII characters, bare CR, and other control characters are unsupported in action text.
Maximum file size is 1 MiB, with at most 100000 expanded actions across the entire configuration. Every segment must contain actions. Unknown fields, null values, and incorrect types are rejected, with segment/action paths in errors.

Preserve supplied text and whitespace. The version 1 example intentionally preserves class: rather than changing it to class=. Both examples above show the schema; the order keystrokes go in is a separate matter, covered by [typing order](typing-order.md).
Indentation belongs to the editor, so a configuration types no leading spaces and reaches a shallower level with backspace. The editor settings this depends on are listed in [editor setup](editor-setup.md), and they have to be confirmed with the user before a demo runs.
Waiting between segments is a playback state, not a JSON action. The advance click is a global user setting, not part of a configuration. Timed waits, paste, loops, scripted mouse movements, arbitrary key combinations, recording, and automatic file navigation remain unsupported.

For creation, validation, saving, and actual editor testing, follow [create-configuration](../skills/create-configuration/SKILL.md). Playback boundaries are described in [runtime](../skills/runtime/SKILL.md).
