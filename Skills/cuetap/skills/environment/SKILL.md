---
name: cuetap-environment
description: Locate the CueTap executable or build it from available source when installation details are unknown or the command is unavailable.
---

# Locate CueTap

Follow the [root Skill](../../SKILL.md) shared rules. This scene is conditional discovery, not a prerequisite for every request.

## Locate or build

Reuse an established executable path. Otherwise try `command -v cuetap`.
If unavailable, look for `<project>/build/products/Release/cuetap` in the known source project. This Skill's source location is `<project>/Skills/cuetap/`, but that relationship may not hold after installation or copying.

When source exists but the executable does not, use [build-local.sh](../../scripts/build-local.sh) with the absolute project root:

```sh
/absolute/path/to/cuetap-skill/scripts/build-local.sh /absolute/path/to/CueTap
```

The helper builds the existing Xcode project, refuses to rebuild while cuetap runs, and prints the executable path. It does not install to PATH. If rebuilding is intended, use the [runtime scene](../runtime/SKILL.md) to quit first. The example is compiled into the binary, so a first startup works even when no `html-demo.json` sits beside the executable; the file is still copied there for reference. The menu icon uses the system SF Symbol `pointer.arrow.ipad.rays`; no external icon assets are needed.
If source or Xcode is unavailable, explain the missing dependency instead of fabricating an installation.

## Compatibility and distribution

This Skill targets CLI 0.4.x, control protocol 1, and configuration formats 1 and 2. For an unknown or changed installation, inspect:

```sh
cuetap version --json
cuetap help
```

Older versions may lack descriptions or configuration management. CueTap is published at https://github.com/CheyYuAn/CueTap and installs with `brew install CheyYuAn/cuetap/cuetap`, which puts the executable at `/opt/homebrew/bin/cuetap` on Apple Silicon or `/usr/local/bin/cuetap` on Intel. Do not invent any other repository, tap, formula, or installation command.

Continue the requested scene with the located executable and known version. Finding the executable alone does not start a resident or prove runtime permissions.
