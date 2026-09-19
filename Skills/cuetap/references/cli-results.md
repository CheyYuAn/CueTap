# CLI results and shared failures

Use `--json` with short commands. Responses contain `ok`, `version`, `protocolVersion`, and `message`, plus relevant `status`, `configurations`, `outputPath`, `diagnostics`, or `error` fields.
Exit codes are 0 for success, 2 for invalid arguments, and 1 for operation failure. Inspect structured error details, not just the exit code.

## Status interpretation

`ok:true` means the requested command succeeded, not that a resident is running. A successful `status` query can return `running:false`.
Live status includes `running`, `pid`, `executable`, `state` (`on`/`off`), `phase` (`off`/`arming`/`playing`/`waiting`/`complete`), `ready`, configuration metadata, `actionCount`, `position`, `hotkey`, and `permissions`.

Configuration metadata includes `configurationID`, `configurationName`, `configurationDescription`, and `configurationPath`. The path is the managed copy, not the external source. Multi-segment status adds `segmentCount`, one-based `segmentIndex`, `segmentName`, `segmentPosition` (executed actions in the current segment), `segmentActionCount`, and `advanceShortcut`. `position` remains the total executed action count across segments. In `waiting`, the current segment is the one just completed.
Stopped status can report the saved path and hotkey without full configuration metadata.
Permissions describe listening, event posting, secure input, and the English input source. A `check` or `validate` response with `running:false` does not establish that the resident is stopped; use `status` when that fact is needed.

## Shared failures

- `not_running`: use [runtime](../skills/runtime/SKILL.md) to start only when the requested operation requires a resident.
- `already_running` from `start --script`: use `load` to change the running resident's configuration.
- `busy`: mutations require the demo off and all keys released. Use `stop` if ending or replacing the demo is within the request, then retry after release.
- `ipc_timeout` or `start_timeout`: outcome is uncertain. Query `status` before repeating a mutation or starting another process. For configuration operations, consult `config list` or the specific output file as needed to establish what happened. Do not blindly repeat a destructive or duplicating operation.
- `invalid_settings`, `protocol_mismatch`, or `not_ready`: investigate the reported cause with the [doctor scene](../skills/doctor/SKILL.md); do not reset data or spawn another namespace as a workaround.

Configuration-specific failures belong to [configuration management](../skills/manage-configurations/SKILL.md), action schema failures to [configuration creation](../skills/create-configuration/SKILL.md), and shortcut failures to [hotkeys](../skills/hotkeys/SKILL.md). Read the relevant scene rather than treating every failure as a reason for a full diagnostic sweep.
