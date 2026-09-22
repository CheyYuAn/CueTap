# Control the resident

Follow the [root Skill](../SKILL.md) shared rules. Invoke only the commands the request needs.

```sh
cuetap start --json
cuetap start --script /absolute/path/demo.json --json
cuetap status --json
cuetap stop --json
cuetap quit --json
```

- `start` returns when the resident is ready; the terminal need not keep focus. An existing resident is reused. Otherwise the saved configuration is selected, or the bundled example is imported on first startup.
- `start --script` imports and selects the file while starting. With a resident already running it fails with `already_running`; use `load` from [manage-configurations](manage-configurations.md) instead.
- `status` reports running state, configuration metadata, progress, hotkey and the resident's permissions. A successful query can report `running: false`. Fields are in [CLI results](cli-results.md).
- `stop` ends the demo and restores the original input source, keeping the resident running.
- `quit` exits the resident and waits for confirmation; it also succeeds when nothing was running.

`serve [--script FILE]`, no subcommand, and the legacy `--script FILE` run in the foreground without `--json`; prefer `start`. Mutations refused with `busy` need the demo off and keys released; use `stop` when ending or replacing the current demo is within the user's request.

## Playback behavior

This is the one place playback is described; other documents link here.

The default toggle hotkey is `cmd+shift+r`; read [hotkeys](hotkeys.md) to change it. The user clicks the starting position, presses the hotkey, releases it fully, and then presses ordinary physical keys. Each fresh key-down advances one action, including cursor moves and Enter; key-up, auto-repeat and modifier-only presses do not. The keys' own functions are intercepted while on. During a demo CueTap switches to an enabled ABC/U.S. input source and restores the original one when the demo ends.

After the last action of the last segment, CueTap keeps intercepting the keyboard for three seconds, so keys typed a moment too late never reach the document, then turns itself off and restores the input source. The hotkey turns it off at any time, including mid-sequence and during those three seconds. Every activation restarts at the first action; there is no pause, resume or automatic document clearing. During playback or arming, switching the foreground application ends the demo.

Between segments of a multi-segment configuration, finishing a segment enters `waiting` with typing still intercepted. The user navigates with plain mouse clicks or scrolling, across files, windows and applications; keyboard shortcuts stay blocked. At the next insertion point they use the advance click, default `cmd+click` meaning Command + left click, which declares the position ready: CueTap does not verify that the click is inside an editor. A complete matching click arms the next segment, binds the foreground application, and reaches the editor as an ordinary positioning click with modifiers removed. Dragging, plain clicks, extra modifiers and clicks during playback do not advance. The last segment enters `complete`, where advance clicks do nothing and the three-second lock runs out.

Waiting and completion still show `State: On` in the menu. Segment progress is in `status --json` and in the menu bar icon's tooltip, not in a menu row. The menu's `Launch at Login` row with its On/Off badge writes or removes `~/Library/LaunchAgents/com.cuetap.agent.plist` for the next login; there is no CLI subcommand for it, so leave it to the user.

CueTap emits exactly the configured actions. It does not read the document, predict the cursor or repair indentation; the editor settings that make this work are in [editor setup](editor-setup.md). If permissions or event monitoring fail, the resident exits rather than silently continuing. When Secure Input turns on, because a password field or the lock screen took the keyboard, a running demo ends and the idle resident keeps waiting; the demo can start again once the secure session is over.

## Resident identity

Normally run one resident. `CUETAP_HOME` changes the data directory and IPC namespace for development and test isolation; do not set it casually or start several interceptors. Reuse the same environment across commands. For a timeout, follow [CLI results](cli-results.md) before retrying.
