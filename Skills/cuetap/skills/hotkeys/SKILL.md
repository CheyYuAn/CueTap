---
name: cuetap-hotkeys
description: Read or change the CueTap global toggle shortcut and explain supported modifier and key combinations.
---

# Configure the hotkey

Follow the [root Skill](../../SKILL.md) shared rules.

```sh
cuetap hotkey get --json
cuetap hotkey set ctrl+option+k --json
```

`get` returns the active or saved shortcut. `set` persists a new shortcut and requires a running resident with the demo off and all keys released. Use [runtime](../runtime/SKILL.md) if starting or stopping is needed for the requested change.

Supported modifiers are `cmd`, `ctrl`, `option`, and `shift`; aliases include `command`, `control`, and `alt`. The main key must be `a-z` or `0-9`. At least two modifiers are required, including `cmd` or `ctrl`. The default is `cmd+shift+r`.

Known logout and lock-screen combinations are rejected. Other system or editor conflicts require a user test when the shortcut changes. Report the accepted shortcut from the command result and have the user test toggling with all keys released afterward. A successful save alone does not prove the absence of shortcut conflicts.

For `invalid_hotkey`, use the reported reason to correct the requested combination; do not silently substitute another shortcut. For `busy` or `not_running`, see [CLI results](../../references/cli-results.md). Do not edit settings directly to bypass command rules.

## Next-segment positioning shortcut

```sh
cuetap advance get --json
cuetap advance set cmd+click --json
cuetap advance set option+shift+click --json
```

This setting is independent of the toggle hotkey and saved in user settings, not in action JSON. Default: `cmd+click`. The mouse button remains left click. Choose one or more unique modifiers from cmd/ctrl/option/shift, using the same aliases as the toggle hotkey. Plain click, keyboard main keys, and repeated modifiers are rejected with `invalid_advance_shortcut`.

`get` works while stopped. `set` requires a running resident, Demo Off, and all keys and the left mouse button released. Match modifiers exactly; an extra modifier does not activate the gesture. Test the changed gesture in the intended editor: it must position a single caret without triggering the editor's native modifier-click action, then accept typing only after all keys/buttons release. See [runtime](../runtime/SKILL.md) for segment boundaries.
