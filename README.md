<h1 align="center">CueTap</h1>

<p align="center">
  Type prepared code during a live demo, one keystroke at a time.
</p>

<p align="center">
  <a href="LICENSE"><img alt="license MIT" src="https://img.shields.io/badge/license-MIT-blue"></a>
  <img alt="version 0.4.0" src="https://img.shields.io/badge/version-0.4.0-brightgreen">
  <img alt="macOS 26.3+" src="https://img.shields.io/badge/macOS-26.3%2B-lightgrey">
  <img alt="no network" src="https://img.shields.io/badge/network-none-informational">
  <a href="https://github.com/CheyYuAn/CueTap/stargazers"><img alt="stars" src="https://img.shields.io/github/stars/CheyYuAn/CueTap"></a>
  <a href="https://github.com/CheyYuAn/CueTap/network/members"><img alt="forks" src="https://img.shields.io/github/forks/CheyYuAn/CueTap"></a>
</p>

<p align="center">
  <a href="#why">Why</a> &bull;
  <a href="#requirements">Requirements</a> &bull;
  <a href="#install">Install</a> &bull;
  <a href="#quick-start">Quick start</a> &bull;
  <a href="#configurations">Configurations</a> &bull;
  <a href="#using-it-with-an-ai-agent">AI agent</a>
</p>

<p align="center">
  <img src="assets/menu.webp" width="302" alt="The CueTap menu bar item, showing demo state, the advance shortcut, and the configuration list expanding in place">
</p>

CueTap types prepared code for you during a live demo, one keystroke at a time.

You press a key, it emits the next action from a configuration file. Press again, it emits the one after that. Whatever you actually type is discarded, so the code that lands on screen is exactly what you prepared, at whatever pace your talking happens to take.

It is a single macOS command line tool with a menu bar icon. No window, no Dock icon, no recording, no network access.

## Why

Typing code live in front of an audience goes wrong in predictable ways. You make typos while explaining something, you lose your place, or you type perfectly and it looks suspiciously rehearsed. Pasting the whole block skips the part people came to see.

CueTap keeps the performance of typing without the risk. You improvise the talking; the characters are already decided.

## What it looks like in use

Prepare a configuration, open your editor, put the cursor where the code should go, press the toggle hotkey. Then type anything, with any rhythm you like. Each key you press advances the demo by one action.

A configuration can hold several segments, for code that belongs in different places. When a segment ends, CueTap waits and keeps swallowing your keystrokes, so you can navigate to the next spot with the mouse, across files, windows and applications. Command-click where the next segment should start and typing resumes there.

After the last segment, the keyboard stays locked for three seconds to absorb any keys you pressed a beat too late, then the demo shuts itself off.

## Requirements

macOS 26.3 or later, Apple Silicon or Intel.

CueTap intercepts and emits keyboard events, so macOS requires you to grant two permissions by hand in System Settings, under Privacy & Security:

- Accessibility
- Input Monitoring

Grant them to whatever runs CueTap. If you launch it from Terminal, grant them to Terminal.

CueTap also forces the ABC/U.S. input source while a demo runs, and restores your previous one when it stops. This keeps an IME from rewriting what gets typed.

## Install

### Homebrew

```
brew install CheyYuAn/cuetap/cuetap
```

### Manual

Download the archive from the Releases page, then:

```
xattr -d com.apple.quarantine cuetap
sudo mv cuetap html-demo.json /usr/local/bin/
```

The `xattr` line removes the quarantine flag macOS puts on anything a browser downloaded. Without it you get "Apple cannot check it for malicious software" and no way to proceed. Homebrew downloads do not carry that flag, which is why the Homebrew path skips this step.

### From source

Requires Xcode 27 or later.

```
git clone https://github.com/CheyYuAn/CueTap.git
cd CueTap
Skills/cuetap/scripts/build-local.sh "$PWD"
```

The executable lands in `build/products/Release/cuetap`.

## A note on upgrades

CueTap ships with an ad-hoc signature rather than a paid Apple Developer certificate. macOS identifies a program by its signature when deciding whether it still holds the permissions you granted, and an ad-hoc signature changes with every build.

In practice this means that after upgrading, CueTap may start but do nothing when you press the hotkey. Go back to System Settings and re-enable it under Accessibility and Input Monitoring. Run `cuetap doctor` if you want to confirm that is what happened.

## Quick start

```
cuetap start
```

This starts the resident process, puts the icon in the menu bar, and loads the bundled example. Then open `tests/test.html` in an editor, put the cursor inside the first input area, press Command-Shift-R, and type.

To check what is loaded:

```
cuetap status --json
```

To stop the current demo but keep the process running:

```
cuetap stop
```

To shut down completely:

```
cuetap quit
```

## Configurations

A configuration is a JSON file listing the actions to emit. Actions are either literal text or a named key, optionally repeated.

```json
{
  "version": 2,
  "name": "My Demo",
  "description": "What this configuration is for.",
  "segments": [
    {
      "name": "Segment 1",
      "actions": [
        { "type": "text", "value": "<div></div>" },
        { "type": "key", "key": "left", "count": 7 },
        { "type": "text", "value": " class=\"body\"" }
      ]
    }
  ]
}
```

Drop a file into `~/Library/Application Support/CueTap/configurations/` and it shows up in the menu and in `cuetap config list`. You can also import one from anywhere:

```
cuetap load /path/to/demo.json
```

CueTap copies imported files into its own directory and never modifies the original.

CueTap emits exactly what the configuration says. It does not read your document, predict the cursor, or fix indentation. Your editor's auto-indent and auto-closing brackets will still do their thing, so test a new configuration in the editor you will actually present with.

The full format is documented in `Skills/cuetap/references/configuration.md`.

## Commands

Run `cuetap --help` for the complete list. Every command accepts `--json`.

Process control is `start`, `stop`, `quit` and `status`. Configuration management is `config list`, `config use`, `config rename`, `config export`, `config remove`, plus `load` and `reload`. Shortcuts are `hotkey get/set` and `advance get/set`. Troubleshooting is `doctor` and `validate`.

Configurations and shortcuts can only be changed while no demo is running.

## Using it with an AI agent

`Skills/cuetap/` is an Agent Skill. Point a coding agent at it and you can ask for a configuration in plain language: give it the code you plan to demo, and it produces, imports and selects the configuration for you.

Starting the demo is always left to you, at the keyboard, in front of the audience.

## Privacy

CueTap makes no network connections and never logs what you type. The startup log at `~/Library/Logs/CueTap/runtime.log` records process events only.

## License

MIT. See LICENSE.
