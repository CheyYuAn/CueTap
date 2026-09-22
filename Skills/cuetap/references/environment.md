# Locate CueTap

Follow the [root Skill](../SKILL.md) shared rules. This is conditional discovery, not a prerequisite for every request.

## Locate or build

Reuse an established executable path. Otherwise try `command -v cuetap`; Homebrew installs put it at `/opt/homebrew/bin/cuetap` on Apple Silicon or `/usr/local/bin/cuetap` on Intel. If unavailable, look for `<project>/build/products/Release/cuetap` in the known source project. This Skill ships at `<project>/Skills/cuetap/`, but that relationship may not hold after installation or copying.

When source exists but the executable does not, build it with [build-local.sh](../scripts/build-local.sh) and the absolute project root:

```sh
/absolute/path/to/cuetap-skill/scripts/build-local.sh /absolute/path/to/CueTap
```

The helper builds the existing Xcode project, refuses to rebuild while cuetap runs, and prints the executable path. It does not install to PATH. If rebuilding is intended, quit the resident first via [runtime](runtime.md). The bundled example is compiled into the binary, so a first start works even without `html-demo.json` beside the executable. If source or Xcode is unavailable, explain the missing dependency instead of fabricating an installation.

VS Code is not a dependency of the executable. `cuetap compile` carries the rules of every language VS Code defines and reads an installed VS Code only for newer files, third-party language extensions and the user's settings. The demo itself is played in VS Code, the only editor the profiles describe.

## Compatibility and distribution

This Skill targets CLI 0.5.x, control protocol 1 and configuration formats 1 and 2. For an unknown or changed installation, inspect:

```sh
cuetap version --json
cuetap help
```

Older versions may lack descriptions, configuration management, `compile`, `diff` or `profiles`. CueTap is published at https://github.com/CheyYuAn/CueTap and installs with `brew install CheyYuAn/cuetap/cuetap`. Do not invent any other repository, tap, formula or installation command.

Continue the requested scene with the located executable and known version. Finding the executable alone does not start a resident or prove runtime permissions.
