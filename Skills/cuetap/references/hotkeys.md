# Configure the hotkey and the advance click

Follow the [root Skill](../SKILL.md) shared rules.

## Toggle hotkey

```sh
cuetap hotkey get --json
cuetap hotkey set ctrl+option+k --json
```

`get` returns the active or saved shortcut. `set` persists a new shortcut and needs a running resident with the demo off and all keys released; use [runtime](runtime.md) if starting or stopping is part of the requested change.

Supported modifiers are `cmd`, `ctrl`, `option` and `shift`, with the aliases `command`, `control` and `alt`. The main key is `a-z` or `0-9`. At least two modifiers are required, one of them `cmd` or `ctrl`. The default is `cmd+shift+r`.

Known logout and lock-screen combinations are rejected. Other system or editor conflicts only show up when the user tries the shortcut, so report the accepted shortcut from the result and have the user test toggling with all keys released. A successful save does not prove the absence of conflicts.

For `invalid_hotkey`, correct the combination from the reported reason; do not substitute another shortcut on your own. For `busy` or `not_running`, see [CLI results](cli-results.md). Do not edit the settings file to bypass command rules.

## Next-segment advance click

```sh
cuetap advance get --json
cuetap advance set cmd+click --json
cuetap advance set option+shift+click --json
```

This setting is independent of the toggle hotkey and saved in user settings, not in any configuration. The default is `cmd+click`. The button is always the left one; choose one or more distinct modifiers from cmd, ctrl, option and shift, with the same aliases as the hotkey. A bare `click`, keyboard keys and repeated modifiers are rejected with `invalid_advance_shortcut`.

`get` works while stopped. `set` needs a running resident with the demo off and all keys and the left mouse button released. Modifiers must match exactly; an extra one does not activate the gesture. Have the user test a changed gesture in the intended editor: it must place a single caret without triggering the editor's own modifier-click action. How the click fits into playback is in [runtime](runtime.md).
