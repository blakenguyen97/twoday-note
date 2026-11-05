<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="Brand/TwodayNote-lockup-dark.svg">
    <img src="Brand/TwodayNote-lockup-light.svg" alt="TwodayNote" width="420">
  </picture>
</p>

<p align="center">
  A tiny macOS menu bar app for jotting down tasks, notes, and ideas for today and the next two days, with a Pomodoro focus timer.
</p>

<p align="center">
  <img src="docs/images/popover.png" alt="The TwodayNote popover: today's tasks, an idea, a note, and a focus session counting down" width="386">
</p>

## Features

- **Lives in the menu bar.** No Dock icon, no window to manage. Click the icon or press **⌃⌥N** from any app.
- **Today, tomorrow, and the day after.** Three tabs, switch with **⌘1 ⌘2 ⌘3**.
- **Four kinds of blocks.** Type a prefix at the start of a line:

  | Prefix | Block |
  | --- | --- |
  | *(none)* or `[] ` | Task with a checkbox |
  | `- ` | Note |
  | `* ` | Idea |
  | `# ` | Heading |

- **Edit in place.** Click any text to change it, drag to reorder, right-click to change its kind, move it to another day, or delete it. Deletes can be undone.
- **Nothing falls through.** Unfinished tasks from earlier days move to the top of today, marked with the day they came from.
- **Count in the icon.** The menu bar icon shows how many tasks are left today, and goes blank when you're done.
- **Focus timer.** A 15, 25, 45, or 60 minute countdown at the bottom of the popover. The time left runs next to the menu bar icon, and a sound plays when it's over.
- **Settings.** Launch at login, global shortcut, menu bar count, carry-over, and accent color.

The interface is in Vietnamese.

## Requirements

- macOS 26 or later
- Swift 6.2 or later. The Command Line Tools are enough; Xcode is not needed.

## Install

```sh
git clone https://github.com/blakenguyen97/twoday-note.git TwodayNote
cd TwodayNote
./build.sh --open
```

`build.sh` builds a release binary, wraps it in an app bundle, signs it, installs it to `~/Applications/TwodayNote.app`, and opens it. It signs with your Apple Development certificate if you have one, and ad hoc otherwise.

To start TwodayNote when you log in, turn on **Mở cùng macOS** in Settings (••• › Cài đặt…).

## Your data

Everything stays on your Mac, in one JSON file:

```
~/Library/Application Support/TwodayNote/notes.json
```

There is no account, sync, or network access.

## Development

| Task | Command |
| --- | --- |
| Build and install | `./build.sh` (add `--open` to restart the app) |
| Unit tests | `tools/test.sh` |
| Self-test on the real app (temporary data) | `tools/selftest.sh` |
| Screenshots in light and dark mode | `tools/snap.sh` → `/tmp/TwodayNote-shots/` |
| Spacing check | `tools/grid-lint.sh` |

`tools/snap.sh` opens the popover and takes keyboard focus for a few seconds while it runs.

The app is a Swift package with no Xcode project. [CLAUDE.md](CLAUDE.md) has the build rules and notes on building with only the Command Line Tools.
