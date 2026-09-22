---
name: cuetap
description: Create, select, and manage CueTap keyboard demo configurations through its CLI, change global hotkeys, and diagnose problems on request. Use when the user asks an agent to prepare or operate a CueTap demo.
---

# CueTap

Respond in the language used in the user's messages. The Skill is written in English; conversation need not be. Preserve CLI commands, JSON keys, and user-provided content.

CueTap is a macOS CLI written in Swift. It replays keystrokes prepared in advance, whatever they spell: code, prose, commands, form input. One executable provides both the resident process and control commands. Its menu bar shows `State: On/Off` with the toggle shortcut, the advance shortcut, `Config: <name>`, `Launch at Login`, `Open Configurations Folder`, `Stop CueTap`, and `Quit CueTap`. Configuration choices expand inline using native menu controls. There is no main window, Dock icon, or separate Swift App. Use the CLI for control.

## Choose the relevant scene

Read only the scene needed for the user's task. These are local modules of this Skill, not separate installations or agents.

- Locate, build, or identify an unknown CLI installation: [environment](skills/environment/SKILL.md).
- Turn supplied text into a configuration with `cuetap compile`, or change one: [create-configuration](skills/create-configuration/SKILL.md).
- Find, import, select, rename, export, or remove configurations: [manage-configurations](skills/manage-configurations/SKILL.md).
- Start the resident, inspect progress, stop a demo, or quit: [runtime](skills/runtime/SKILL.md).
- Read or change the toggle hotkey or next-segment click shortcut: [hotkeys](skills/hotkeys/SKILL.md).
- Investigate a reported failure or a request for diagnosis: [doctor](skills/doctor/SKILL.md).

Two references cut across the scenes and are read together with whichever one applies: [editor setup](references/editor-setup.md) for the editor settings every demo depends on, and [typing order](references/typing-order.md) for the order keystrokes go in.

## Shared rules

Reuse tested, unchanged configurations directly. Do not add routine `check`, `doctor`, `validate`, `status`, action-preview, or approval steps before every demo. Validate and test new or changed action sequences during preparation. Use `doctor` only for requested troubleshooting.

A demo only produces the intended text in an editor where nothing types on the user's behalf. Before the first demo in a given editor, tell the user which settings to turn off and ask them to confirm; see [editor setup](references/editor-setup.md). Keystroke order is computed by `cuetap compile` from the target text and an editor profile, never written by hand; [typing order](references/typing-order.md) explains what it produces. After a demo, `cuetap diff` compares the typed file with the target.

Tell the user whenever the configuration will type something different from what they supplied, and let them decide. CueTap sends the 95 printable ASCII characters only, so any other script or punctuation has to be raised rather than quietly replaced.

The user positions the cursor and starts playback with the hotkey. There is no CLI command to start typing automatically. Do not inject test keystrokes into the user's editor or claim an unperformed editor test passed. CueTap executes the configured order without inferring document structure or repairing indentation.

In examples, `cuetap` means the established executable path. Reuse it; consult the environment scene only when needed. Quote shell arguments and use absolute file paths. Short commands support `--json`; interpret their results using [CLI results](references/cli-results.md) when needed.

When moving between scenes, retain the executable path, configuration ID and managed path, requested outcome, and already observed results. Do not restart discovery or repeat successful mutations merely because the task crosses document boundaries.

Keep configurations and source local. Do not upload them as part of demo preparation. Report the actual requested outcome and full paths of created or imported files.
