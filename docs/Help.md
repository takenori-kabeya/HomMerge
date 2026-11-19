# HomMerge Help

HomMerge is a Mac-only file and folder comparison tool. Use it to compare two files or folder trees, merge changes, and copy or delete items.

## Getting started

1. Choose **File → Open Left…** and **File → Open Right…** (or drop paths into the panes).
2. Choose **File → Compare** (⌘↩) to start a comparison.
3. For folders, browse differences in the table; for files, review highlighted hunks in the dual panes.

You can also:

- Choose **File → New Window** (⌘N) or **New Tab** (⌘T).
- Select two items in Finder and use **Services → Compare with HomMerge**.
- Drag one or two files onto the HomMerge icon (Dock or Finder) to open or compare them.

## File comparison

- Navigate differences with the **Diff** menu or toolbar.
- Copy the current difference left or right, optionally advancing to the next difference.
- Save each side with **File → Save Left** (⌘S) or **Save Right** (⇧⌘S).
- Undo and redo merge edits with **Edit → Undo** / **Redo**.

## Folder comparison

- Refresh the tree with **Diff → Refresh** (⌘R).
- Copy selected items to the other side, or move them to Trash.
- Open a file compare for selected paired (or cross-name) items with **Diff → Compare Selected Folder Files**.

## Keyboard shortcuts

| Action | Shortcut |
|--------|----------|
| New Window | ⌘N |
| New Tab | ⌘T |
| Open Left… | ⌘O |
| Open Right… | ⇧⌘O |
| Compare | ⌘↩ |
| Close Tab | ⌘W |
| Save Left | ⌘S |
| Save Right | ⇧⌘S |
| Undo / Redo | ⌘Z / ⇧⌘Z |
| Refresh | ⌘R |
| First Difference | ⇧⌥⌘↑ |
| Previous Difference | ⌥⌘↑ |
| Next Difference | ⌥⌘↓ |
| Last Difference | ⇧⌥⌘↓ |
| Current Difference | ⌘↩ |
| Nearest Difference at Caret | ⌥⌘/ |
| Copy Difference to Right | ⌥⌘→ |
| Copy Difference to Left | ⌥⌘← |
| Copy Difference to Right and Next | ⇧⌥⌘→ |
| Copy Difference to Left and Next | ⇧⌥⌘← |
| HomMerge Help | ⌘? |

## App Sandbox notes

Official builds run under **App Sandbox**. Open panels, drag-and-drop, and Finder Services grant file access. Sessions store security-scoped bookmarks so paths can be restored after relaunch.

Launching with raw path arguments (for example `open -a HomMerge --args /path/a /path/b`) may fail under the sandbox because those URLs are not user-selected. Prefer the UI, Services, or drag-and-drop.

## More information

- Source and documentation: [HomMerge on GitHub](https://github.com/takenori-kabeya/HomMerge)
- Report problems: [GitHub Issues](https://github.com/takenori-kabeya/HomMerge/issues)
