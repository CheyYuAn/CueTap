# CLI results and shared failures

Use `--json` with short commands. Responses contain `ok`, `version`, `protocolVersion`, and `message`, plus relevant `status`, `configurations`, `outputPath`, `diagnostics`, `compile`, `comparison`, `profiles`, or `error` fields.
Exit codes are 0 for success, 2 for invalid arguments, and 1 for operation failure. Inspect structured error details, not just the exit code.

## Status interpretation

`ok:true` means the requested command succeeded, not that a resident is running. A successful `status` query can return `running:false`.
Live status includes `running`, `pid`, `executable`, `state` (`on`/`off`), `phase` (`off`/`arming`/`playing`/`waiting`/`complete`), `ready`, configuration metadata, `actionCount`, `position`, `hotkey`, and `permissions`.

Configuration metadata includes `configurationID`, `configurationName`, `configurationDescription`, and `configurationPath`. The path is the managed copy, not the external source. Multi-segment status adds `segmentCount`, one-based `segmentIndex`, `segmentName`, `segmentPosition` (executed actions in the current segment), `segmentActionCount`, and `advanceShortcut`. `position` remains the total executed action count across segments. In `waiting`, the current segment is the one just completed. `complete` lasts three seconds and then `state` becomes `off` without any command.
Stopped status can report the saved path and hotkey without full configuration metadata.
Permissions describe listening, event posting, secure input, and the English input source. A `check` or `validate` response with `running:false` does not establish that the resident is stopped; use `status` when that fact is needed.

## Profiles, compile and diff results

`profiles` returns a `profiles` array sorted by language id, each entry with `name` (`vscode-<language id>`), `languageId`, `source` (`built-in` for `plain`, `bundled` when the rules ship inside the executable, `installed` when an installed VS Code or one of its extensions defines the language, which is then the definition compile uses), `rulesSource` (the origin of the bundled snapshot or the installed file's path), `extensions` (the file extensions the language claims) and `tags` (whether tag pairing is on by default). It never fails on a machine without VS Code; the bundled entries are always present.
`compile` returns `outputPath` and a `compile` object with `profile`, `rulesSource` (the language-configuration file read, or a note that the bundled snapshot was used), `tabSize`, `insertSpaces`, `tags`, `actionCount`, one `segments` entry per target with `name`, `source`, `lines`, `actions`, and `droppedTrailingNewline`, plus `settingsFile` (the user settings path, and the workspace `.vscode/settings.json` when one sits above a target) and `settings` for VS Code profiles: each finding has `severity` (`warning` or `info`), `key`, `expected`, `actual` and `note`. A final newline in the target is never typed; editors add it on save.
Compile failures: `unsupported_character` lists every non-ASCII character with line and column, to be settled with the user; `unsupported_tab` is a tab outside the indentation; `compile_failed` means the editor model could not reproduce the target with CueTap's keys, with the first differing line, or that the target's indentation style (tabs or spaces) does not match the profile; `profile_not_found` means the language id is neither bundled (every language VS Code itself defines) nor provided by an installed VS Code extension; `rules_unreadable` means the rules file could not be read or parsed; `output_exists` asks for another path or `--force`; `target_unreadable` and `output_unwritable` are file errors. Nothing is written on failure.
`diff` takes one or more expected/actual pairs and returns `comparisons`, one entry per pair with the resolved `expected` and `actual` paths and a `comparison` object: `identical`, and when different `line`, `column`, `expected`, `actual` for the first differing line, plus `trailingNewline` describing whether the two files end the same way, which is reported but never counted. `comparison` alone carries the first differing pair, or the only pair. Any difference exits 1 with `text_mismatch` naming each differing pair; identical files exit 0.

## Shared failures

- `not_running`: use [runtime](runtime.md) to start only when the requested operation requires a resident.
- `already_running` from `start --script`: use `load` to change the running resident's configuration.
- `busy`: mutations require the demo off and all keys released. Use `stop` if ending or replacing the demo is within the request, then retry after release.
- `ipc_timeout` or `start_timeout`: outcome is uncertain. Query `status` before repeating a mutation or starting another process. For configuration operations, consult `config list` or the specific output file as needed to establish what happened. Do not blindly repeat a destructive or duplicating operation.
- `invalid_settings`, `protocol_mismatch`, or `not_ready`: investigate the reported cause with the [doctor](doctor.md); do not reset data or spawn another namespace as a workaround.

Configuration-specific failures belong to [manage-configurations](manage-configurations.md), action schema failures to [create-configuration](create-configuration.md), and shortcut failures to [hotkeys](hotkeys.md). Read the relevant scene rather than treating every failure as a reason for a full diagnostic sweep.
