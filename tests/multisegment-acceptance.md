# Multi-segment and menu acceptance

Use tests/html-demo.json: 38, 38, and 39 actions, ending in hello, world, and cuetap. tests/single-segment-demo.json preserves the original version 1 fixture for compatibility tests.

## Menu layout

1. Open the menu with the demo off. Top to bottom: State with the toggle shortcut, Next segment with the advance shortcut, Config with the current name and a disclosure button, a separator, Launch at Login with an On/Off badge, Open Configurations Folder in grey, a separator, Stop CueTap (disabled while off) and Quit CueTap.
2. Every row's text must start on the same left edge, including the two custom rows and the configuration choices below their icons. Each choice icon must be centred on its name's line, and every name must start at the same x whatever its icon. No checkmark may appear anywhere in the menu.
3. Long names must end in an ellipsis, never in a cut-off word, and the full name must appear in the tooltip. `Open Configurations Folder` must always read in full.

## Configuration folder and list

1. Expand Config using the native disclosure button on its right. Choices must appear inside the same menu; there must be no side submenu or separate window. Closing and reopening the menu must return to the collapsed form.
2. Open Configurations Folder and copy a valid JSON there. Reopen the menu and verify it appears without load/import commands. Select it and verify the Config row and the persisted selection after restart.
3. Add a malformed JSON beside valid files. It must appear disabled with a warning icon and an error tooltip. Valid files must still be selectable. Remove the malformed test file afterward.
4. While the demo is on, configuration switching is unavailable. Stop the demo and release keys, then confirm switching works again.

## Launch at Login

1. Click Launch at Login and confirm the badge turns On and `~/Library/LaunchAgents/com.cuetap.agent.plist` exists. No second cuetap process may start at that moment.
2. Log out and back in: exactly one CueTap must be running, from the path recorded in the property list.
3. Click it again, confirm the badge turns Off and the file is gone, and that the running process keeps working.

## Three positions

1. Open tests/test.html locally. Select HTML Demo, click the first field, press the toggle shortcut, and release all keys.
2. Press 38 fresh ordinary keys. Confirm the exact first text and caret. Extra keys must do nothing.
3. Plain-click the second field and type a few keys. It must remain empty. Scroll, right-click, or Command-drag without advancing.
4. Command-left-click the second field. Release mouse and Command. Type 38 times. Confirm world and no link navigation, definition jump, selection extension, or extra caret.
5. Command-left-click the third field, release, and type 39 times. Confirm cuetap. More combination clicks and typing must not restart or advance.
6. Keep typing right after the last action: nothing may reach the document. About three seconds later the demo turns itself off, the State row reads Off, and ordinary typing and the original input source return without pressing the toggle.

## Real editors and control

Repeat the three segments in three empty files, then with the second file in another editor application. Navigate with ordinary mouse clicks while waiting. Advance-click only inside the intended text area. Waiting allows application changes; switching applications while actually playing still cancels the whole demo.

Change the advance shortcut with cuetap advance set option+click while Off. Test exact matching and restart persistence, then restore cmd+click. Test toggle-off while waiting and while releasing an advance click. Re-enable and confirm segment 1 starts from zero. No stuck Command/Shift, leaked key-up, or repeated segment transition is acceptable.

This document is a procedure, not a claim that human editor acceptance has passed. Native automated tests consume test events before they reach user documents; they cannot prove every editor's click behavior.
