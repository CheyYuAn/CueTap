---
name: cuetap
description: Create, select, and manage CueTap keyboard demo configurations through its CLI, change global hotkeys, and diagnose problems on request. Use when the user asks an agent to prepare or operate a CueTap demo.
---

# CueTap

Respond in the language used in the user's messages. The Skill is written in English; conversation need not be. Preserve CLI commands, JSON keys, and user-provided content.

CueTap is a macOS CLI written in Swift. One executable provides both the resident process and control commands. Its menu bar shows `Demo: On/Off`, `Configuration: <name>`, segment/phase information, and `Quit CueTap`. Configuration choices expand inline using native menu controls. There is no main window, Dock icon, or separate Swift App. Use the CLI for control.

## Choose the relevant scene

Read only the scene needed for the user's task. These are local modules of this Skill, not separate installations or agents.

- Locate, build, or identify an unknown CLI installation: [environment](skills/environment/SKILL.md).
- Turn supplied code into a configuration, or change its actions: [create-configuration](skills/create-configuration/SKILL.md).
- Find, import, select, rename, export, or remove configurations: [manage-configurations](skills/manage-configurations/SKILL.md).
- Start the resident, inspect progress, stop a demo, or quit: [runtime](skills/runtime/SKILL.md).
- Read or change the toggle hotkey or next-segment click shortcut: [hotkeys](skills/hotkeys/SKILL.md).
- Investigate a reported failure or a request for diagnosis: [doctor](skills/doctor/SKILL.md).

## Shared rules

Reuse tested, unchanged configurations directly. Do not add routine `check`, `doctor`, `validate`, `status`, action-preview, or approval steps before every demo. Validate and test new or changed action sequences during preparation. Use `doctor` only for requested troubleshooting.

The user positions the cursor and starts playback with the hotkey. There is no CLI command to start typing automatically. Do not inject test keystrokes into the user's editor or claim an unperformed editor test passed. CueTap executes the configured order without inferring code structure or repairing indentation.

In examples, `cuetap` means the established executable path. Reuse it; consult the environment scene only when needed. Quote shell arguments and use absolute file paths. Short commands support `--json`; interpret their results using [CLI results](references/cli-results.md) when needed.

When moving between scenes, retain the executable path, configuration ID and managed path, requested outcome, and already observed results. Do not restart discovery or repeat successful mutations merely because the task crosses document boundaries.

Keep configurations and source local. Do not upload them as part of demo preparation. Report the actual requested outcome and full paths of created or imported files.
