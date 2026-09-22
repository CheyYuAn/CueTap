# Action configuration formats

Files are UTF-8 JSON. Version 2 is what `cuetap compile` writes: ordered segments, one per insertion position. Version 1 remains supported as a single segment without rewriting existing files. Configurations are produced by the compiler, see [create-configuration](create-configuration.md); the schema is documented so results can be read and old files understood.

## Version 2

Allowed root fields: `version` (2), `name` (nonblank string), `description` (optional string), and `segments` (nonempty array). Root `actions` are not allowed. Each segment has a nonblank `name`, an optional `description`, and a nonempty `actions` array. Array order is segment order; there is no numeric ordering field.

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

Names and descriptions support Unicode and the user's language. They describe intent; they do not locate files, run commands or move the cursor. Missing descriptions default to empty strings.

## Version 1 compatibility

Allowed root fields: `version` (1), `name`, `description`, and `actions`; `segments` is not allowed. Name, description and action rules match version 2.

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

The example intentionally keeps `class:` rather than `class=`; supplied text is preserved as given.

## Actions and limits

A `text` action has only `type` and a nonempty `value`. Text expands into individual characters when loaded; it is not pasted at once, and one fresh physical key-down executes one expanded action.
A `key` action has `type`, `key` and an optional `count`. Supported keys are `left`, `right`, `enter`, `tab` and `backspace`. `count` is a positive integer, default 1; a count of 7 takes seven presses. `left` and `right` are how a sequence gets back inside a pair of symbols or tags and out again; `tab` and `backspace` at a line start are how it corrects the editor's indentation.
Text supports the 95 printable ASCII characters. LF or CRLF becomes one Enter action; a tab character becomes one Tab action. Non-ASCII characters, bare CR and other control characters are rejected.
Maximum file size is 1 MiB, with at most 100000 expanded actions across the configuration. Every segment must contain actions. Unknown fields, null values and wrong types are rejected, with segment and action paths in the error.

Waiting between segments is a playback state, not an action, and the advance click is a user setting, not part of a configuration; see [runtime](runtime.md). Timed waits, paste, loops, mouse movements, arbitrary key combinations, recording and automatic file navigation are unsupported. The order keystrokes go in is covered by [typing order](typing-order.md).
