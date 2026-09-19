---
name: cuetap-doctor
description: Diagnose reported CueTap failures with read-only findings, resident-aware permission status, and startup logs.
---

# Diagnose a reported problem

Follow the [root Skill](../../SKILL.md) shared rules. Use this scene when the user reports failure or requests diagnosis. Do not run it as routine preparation for a working demo.

```sh
cuetap doctor --json
```

`doctor` is read-only. It does not start or repair the resident, write settings, prompt for permission, or change the input source. Its response includes `diagnostics` with executable, data directory, configuration directory, log path, permission scope, and findings.

Each finding has an `id`, `severity` (`pass`, `info`, `warning`, or `error`), `message`, and optional `suggestion`. A stopped resident is informational, not automatically a fault. Error findings return `diagnostic_failed` and exit code 1; read the findings even when the command exits unsuccessfully.

## Follow the relevant finding

- Permissions: `permissionsScope` is `resident` when the resident can be contacted; otherwise it is `command_host`. Terminal, Xcode, and other launch hosts may need separate grants. Ask the user to grant the indicated permission in System Settings. Do not modify TCC or claim to authorize it yourself.
- Executable/version mismatch: use [environment](../environment/SKILL.md) to identify the intended executable. Do not start another interceptor to bypass the mismatch.
- Invalid selection, file, settings, or data directory: inspect the reported path and specific failure. Use [configuration management](../manage-configurations/SKILL.md) for supported operations, or [create-configuration](../create-configuration/SKILL.md) for an action-file repair. Do not reset unrelated data.
- IPC/start timeout: the operation may already have happened. Query `status` and inspect relevant startup diagnostics before retrying a mutation. See [CLI results](../../references/cli-results.md).

Follow the finding's relevant suggestion; do not run all diagnostic commands repeatedly or perform unrelated repairs. Report what failed, what evidence supports the diagnosis, and what remains unverified.

## Logs and legacy check

Startup diagnostics normally live at `~/Library/Logs/CueTap/runtime.log`. Prefer the returned `logPath`. Logs contain diagnostics, not keystroke contents. Migrated logs may be named `legacy-runtime-<id>.log`. With the development-only `CUETAP_HOME` override, logs live in that directory's `logs/` subdirectory.

`cuetap check --json` (legacy `--check`) only checks the invoking command host's permissions and English input source. It is not a required preflight and does not replace the running resident's `status` or resident-scoped diagnostics. Permission failures requiring human authorization must be reported as unresolved until actually addressed.
