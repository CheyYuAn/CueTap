---
name: cuetap
description: Prepare and operate CueTap, the macOS tool that replays prepared keystrokes for live demos, talks and screencasts. Use when the user wants text (code, prose, commands, form input) turned into a CueTap configuration with cuetap compile, wants a configuration selected, imported, renamed or removed, wants the resident started, stopped or queried, wants the hotkey or advance click changed, or reports that a demo typed the wrong thing.
---

# CueTap

Respond in the language used in the user's messages. The Skill is written in English; conversation need not be. Preserve CLI commands, JSON keys, and user-provided content.

CueTap is a macOS command line tool written in Swift. It replays keystrokes prepared in advance, whatever they spell: code, prose, commands, form input. One executable is both the resident process and the control client. The resident shows a menu bar item and nothing else: no window, no Dock icon. The menu lists `State: On/Off` with the toggle hotkey, `Next segment` with the advance shortcut (hidden for single-segment configurations), a `Config: <name>` row whose disclosure button expands the configuration list in place, `Launch at Login` with an On/Off badge, `Open Configurations Folder`, `Stop CueTap` (enabled only while a demo runs) and `Quit CueTap`. There are no checkmarks anywhere in the menu; the selected configuration is the name shown on the Config row. Agents use the CLI; every command takes `--json`.

## Who does what

The agent prepares: it writes the target text, compiles it into a configuration, saves and selects it, and checks the typed result afterwards. The user performs: they set up the editor, place the cursor, press the hotkey and type. There is no CLI command that starts typing, and the agent never injects keystrokes into the user's editor or claims an editor test it did not see.

## Choose the relevant scene

Read only the scene the task needs. They are documents of this Skill, not separate skills.

- Turn supplied text into a configuration with `cuetap compile`, or change one: [create-configuration](references/create-configuration.md).
- Find, import, select, rename, export, or remove configurations: [manage-configurations](references/manage-configurations.md).
- Start the resident, inspect progress, stop a demo, or quit, and how playback behaves: [runtime](references/runtime.md).
- Read or change the toggle hotkey or the next-segment click: [hotkeys](references/hotkeys.md).
- Investigate a reported failure: [doctor](references/doctor.md).
- Locate or build the executable when its location or version is unknown: [environment](references/environment.md).

Cross-cutting references: [editor setup](references/editor-setup.md) for the editor settings every demo depends on, [typing order](references/typing-order.md) for what the compiler produces and how to read a `diff` mismatch, [configuration format](references/configuration.md) for the JSON schema, and [CLI results](references/cli-results.md) for result fields and error codes.

## Shared rules

The editor must have nothing that types on the user's behalf and must keep its own automatic indentation. Before the first demo in a given editor, confirm the settings in [editor setup](references/editor-setup.md) with the user; `cuetap compile` checks the VS Code ones it can read and reports the rest for confirmation. Profiles are `vscode-<language id>` for VS Code, the only code editor supported, and `plain` for fields with no editor behaviour such as a terminal, a browser form or a notes app.

Configurations come from `cuetap compile`, never from hand-written or hand-edited action sequences. CueTap sends the 95 printable ASCII characters plus Enter, Tab, Backspace, Left and Right; the compiler refuses anything else, and the agent raises those characters with the user instead of substituting silently. Whenever the configuration will type something different from what the user supplied, say so before compiling and let the user decide.

Reuse tested, unchanged configurations directly. Do not add routine `check`, `doctor`, `validate`, `status` or preview steps before a demo; `doctor` is for reported problems.

In examples, `cuetap` means the established executable path. Reuse it across scenes, together with the configuration ID, its managed path and results already observed; do not restart discovery or repeat a mutation that already succeeded. Quote shell arguments and use absolute file paths. Keep configurations and source local; do not upload them as part of preparation. Report the requested outcome and the full paths of files created or imported.
