import Foundation

/// The text behind `cuetap help`, kept apart from the dispatch so the two change independently.
extension CommandRunner {
    static let help = """
    CueTap \(ControlResponse.version): Swift CLI with a menu bar item. No main window or Dock icon.
    cuetap start [--script FILE] [--json]   Start the resident process and return its status
    cuetap status [--json]                Query running state, configuration, progress and hotkey
    cuetap check [--json]                 Check this command host's permissions and input source
    cuetap doctor [--json]                Diagnose a problem on demand; does not modify settings
    cuetap validate [FILE] [--json]       Validate a configuration without intercepting input
    cuetap compile --profile NAME --output FILE TARGET... [--json]
                                          Turn target text files into a configuration for that editor
    cuetap profiles [--json]              List the compile profiles this machine resolves, with file extensions
    cuetap diff EXPECTED ACTUAL [EXPECTED ACTUAL ...] [--json]
                                          Compare what a demo typed with the target text, one pair per segment
    cuetap load FILE [--json]             Import a managed copy and select it while off
    cuetap reload [--json]                Reread the selected managed copy while off
    cuetap config list [--json]           List IDs, names, descriptions and the selected configuration
    cuetap config use ID [--json]         Select a saved configuration while off
    cuetap config rename ID NAME [--json] Rename metadata, keeping the same ID, while off
    cuetap config export ID FILE [--json] Export JSON; never overwrite an existing destination
    cuetap config remove ID [--json]      Delete an unselected configuration while off
    cuetap hotkey get [--json]            Query the active or saved hotkey
    cuetap hotkey set cmd+shift+r [--json] Change and save the hotkey while off
    cuetap advance get [--json]           Query the next-segment click shortcut
    cuetap advance set cmd+click [--json] Set modifiers plus left click while off
    cuetap stop [--json]                  Stop the demo and restore input; keep the process running
    cuetap quit [--json]                  Quit and wait for confirmation
    cuetap version [--json]               Show version and protocol compatibility
    cuetap serve [--script FILE]          Run in the foreground using this same executable
    Legacy --script, --check, --validate, --help and --version remain supported.
    Put JSON files directly in the configurations directory; expand Configuration in the menu to select.
    Version 2 uses ordered segments; version 1 remains a single segment.
    Between segments, use Cmd+left click at the next position, release, then type.
    The advance shortcut is configurable. Plain clicks and dragging do not advance.
    Startup uses the saved managed copy; first startup imports the bundled html-demo.json.
    start --script and load import into ~/Library/Application Support/CueTap/configurations/.
    Import preserves the source. Same-name files with different content get a numbered suffix.
    status returns the managed configurationPath. Edit that file and reload, or load the source again.
    Config selectors accept an exact ID first, otherwise a unique display name. IDs are managed filename stems.
    config list/export work without a resident; use/rename/remove require a running resident in the off state.
    JSON description is optional for old files; new configurations should describe the project and code section.
    doctor is for troubleshooting, not a required step before each demo. It never repairs or starts anything.
    Settings stay in ~/Library/Application Support/CueTap/; logs use ~/Library/Logs/CueTap/.
    validate without FILE always checks html-demo.json beside the executable.
    compile profiles are vscode-<language id>: every language VS Code defines is bundled, an installed VS Code adds its extensions' languages;
    plain is a text field without editor behaviour (terminal, browser field, notes): indentation is typed, nothing is closed for you;
    --rules FILE loads any language-configuration.json. Tag languages get tag pairing; --tags/--no-tags override.
    compile options: --name, --description, --tab-size N, --tabs, --force; each TARGET becomes one segment.
    compile types pairs and tags as both halves plus Left, leaves indentation to the editor and fixes it with Tab or Backspace,
    and reports VS Code user settings that would break the demo.
    diff exits 1 with text_mismatch and the first differing line and column of each pair that differs; a trailing newline is reported, not counted.
    Hotkeys support cmd/ctrl/option/shift and a-z or 0-9; use two modifiers including cmd or ctrl.
    System and application shortcut conflicts require manual testing.
    Focus the target editor and press your hotkey. Completion remains on until toggled off.
    --json returns ok/version/protocolVersion/message/status/error.
    Exit codes: 0 success, 2 invalid arguments, 1 operation failure.
    """
}
