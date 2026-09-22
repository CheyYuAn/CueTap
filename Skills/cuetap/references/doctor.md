# Diagnose a reported problem

Follow the [root Skill](../SKILL.md) shared rules. Use this when the user reports a failure or asks for a diagnosis, not as routine preparation.

```sh
cuetap doctor --json
```

`doctor` is read-only: it does not start or repair the resident, write settings, prompt for permission or change the input source. The response's `diagnostics` carries the executable, data directory, configuration directory, log path, permission scope and findings. Each finding has `id`, `severity` (`pass`, `info`, `warning` or `error`), `message` and an optional `suggestion`. A stopped resident is informational, not a fault. Error findings return `diagnostic_failed` with exit code 1; read the findings even then.

## Follow the relevant finding

- Secure Input: a password field or the lock screen holds the keyboard. No demo can run until it ends; the resident does not need a restart.
- Permissions: `permissionsScope` is `resident` when the resident could be contacted, otherwise `command_host`. Terminal, Xcode and other launch hosts each need their own grant. Ask the user to grant the indicated permission in System Settings; do not modify TCC or claim to have authorized anything.
- Executable or version mismatch: identify the intended executable with [environment](environment.md). Do not start another interceptor to work around it.
- Invalid selection, file, settings or data directory: inspect the reported path and failure. Use [manage-configurations](manage-configurations.md) for supported operations or [create-configuration](create-configuration.md) to rebuild a broken configuration. Do not reset unrelated data.
- IPC or start timeout: the operation may already have happened. Query `status` and read the startup log before retrying a mutation; see [CLI results](cli-results.md).

Follow the finding's suggestion; do not run every diagnostic repeatedly or perform unrelated repairs. Report what failed, the evidence, and what remains unverified.

## Logs and the legacy check

Startup diagnostics are in `~/Library/Logs/CueTap/runtime.log`; prefer the returned `logPath`. Logs contain process events, never keystrokes. Migrated logs are named `legacy-runtime-<id>.log`. With the development-only `CUETAP_HOME` override, logs are in that directory's `logs/`.

`cuetap check --json` (legacy `--check`) checks only the invoking command host's permissions and English input source. It is not a required preflight and does not replace the running resident's `status`. Permission failures that need the user's authorization stay unresolved until the user grants them.
