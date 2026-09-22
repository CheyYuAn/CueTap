---
name: cuetap-runtime
description: Start or query the CueTap resident, stop the current demo, or quit, and explain physical-keyboard playback behavior.
---

# Control the resident

Follow the [root Skill](../../SKILL.md) shared rules. Invoke only the commands needed for the request, not the entire list below as a checklist.

```sh
cuetap start --json
cuetap start --script /absolute/path/demo.json --json
cuetap status --json
cuetap stop --json
cuetap quit --json
```

- `start` returns when the resident is ready; the terminal need not retain focus. An existing resident is reused. Otherwise the saved managed configuration is selected, or the bundled example is imported on first startup.
- `start --script` imports and selects the file while starting. An existing resident produces `already_running`; use `load` from [configuration management](../manage-configurations/SKILL.md) instead.
- `status` reports running state, configuration metadata, progress, hotkey, and resident permissions. A successful query can report `running:false`. Interpret fields using [CLI results](../../references/cli-results.md).
- `stop` ends the demo and restores the original input source, keeping the resident running.
- `quit` exits the resident and waits for confirmation. It also succeeds if already stopped.

`serve [--script FILE]`, no subcommand, and legacy `--script FILE` run in the foreground and do not support `--json`. Prefer `start` for ordinary Agent operation. A busy mutation requires the demo to be off and keys released; use `stop` if ending or replacing the current demo is within the user's request.

## Playback behavior

The default hotkey is `cmd+shift+r`; use the current configured shortcut if changed. To change it, read [hotkeys](../hotkeys/SKILL.md).

The user clicks the starting position, activates the hotkey, fully releases it, and presses ordinary physical keys. Each fresh key-down advances one action, including cursor moves and Enter. Key-up, auto-repeat, and modifier-only presses do not advance. Original ordinary-key functions are intercepted while on.

After the last action of the last segment, CueTap keeps intercepting the keyboard for three seconds, so keys typed a moment too late never reach the document, and then turns itself off and restores the input source. The hotkey turns it off at any time, including mid-sequence and during those three seconds. Every activation restarts at the first action; there is no pause/resume or automatic document clearing. During playback or arming, switching the foreground application ends the demo. While waiting between segments, switching files, windows, and applications is allowed.

For version 2, finishing a non-final segment enters `waiting`, with normal typing still intercepted. Navigate using plain mouse clicks or scrolling. At the next insertion point, use the advance shortcut (default `cmd+click`, meaning Command + left click). This explicitly declares the next position ready; CueTap does not verify that the click is inside an editor text area. A complete matching click arms the next segment, binds the foreground application, and is delivered with modifiers removed as an ordinary positioning click. Release the mouse and all keys before typing. Dragging, plain clicks, extra modifiers, and clicks during playback do not advance. The last segment enters `complete`, where advance clicks cannot restart it and the three-second lock runs out before the demo ends by itself.

The menu bar also carries a Launch at Login switch, shown with a checkmark. It writes or removes `~/Library/LaunchAgents/com.cuetap.agent.plist` and takes effect at the next login; there is no CLI subcommand for it, so leave it to the user.
Waiting and final completion remain `State: On` in the menu. Segment progress is reported by `status --json` and by the menu bar icon tooltip, not by a menu row. Starting over always means toggling Off then On, restarting at segment 1. Navigation with ordinary keyboard shortcuts remains blocked while waiting; use the mouse. Changing the advance shortcut is covered in [hotkeys](../hotkeys/SKILL.md).

During a demo CueTap switches to an enabled ABC/U.S. input source and restores the original when stopped or when an error ends the session. The user prepares editor settings; CueTap does not calculate or repair indentation. If permissions or event monitoring fail, the session ends rather than silently continuing.

## Resident identity

Normally run one resident. `CUETAP_HOME` changes the data directory and IPC namespace for development/test isolation; do not set it casually or start multiple interceptors during normal operation. Reuse the existing environment across commands. For uncertain timeouts, follow [CLI results](../../references/cli-results.md) before retrying.
