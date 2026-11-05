# TwodayNote

A menu bar app for quick tasks, notes, and ideas for today and tomorrow,
plus a Xem sau list of things to look at later. SwiftUI in an AppKit shell: `NSStatusItem` + `NSPopover`, no Dock icon
(`LSUIElement`), no main window. Data is one JSON file, no server.
Design plan: `docs/DESIGN.md`. UI text is Vietnamese by default, with English
in Settings > Chung > Ngôn ngữ: write every UI string as `L("câu tiếng Việt")`
(`{}` for values) and add its English to `Strings.en` in
`Sources/TwodayNoteKit/Language.swift`; `tools/test.sh` fails on a missing one.
Snapshots in English: `APP_LANG=en tools/snap.sh`.

## Toolchain: Command Line Tools only (no Xcode)

- No SwiftData, `@Model`, or `@Query`: their macro plugin ships with Xcode. Data is
  `Notebook` (Codable, in the Kit) saved to `~/Library/Application Support/TwodayNote/notes.json`.
- No `@State` syntax: in this SDK it is a macro that needs Xcode. Write
  `private let text = State(initialValue: "")` and use `.wrappedValue` / `.projectedValue`.
  `@Observable`, `@Environment`, `@FocusState`, `@AppStorage`, `@Bindable` work.
- Unit tests: `tools/test.sh` (passes the swift-testing plugin path).
- With Xcode installed, all of the above works the template's normal way.

## Layout

- `Sources/TwodayNote/` the app. `App.swift`: status item, popover, Settings window, hidden main menu (Edit shortcuts), global hotkey ⌃⌥N (`HotKey.swift`). `NotesView.swift`: the popover. `Models.swift`: `AppModel`, `Store`, `Prefs`.
- `Sources/TwodayNoteKit/` rules and data logic with no SwiftUI. Tests in `Tests/TwodayNoteKitTests/`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `~/Applications/TwodayNote.app`.
- `Brand/` logos: wordmark and lockup, light and dark, SVG and PNG. `build.sh` copies the two lockup SVGs (logo and name) into the app; the popover header shows them (`Lockup` in `NotesView.swift`).
- `Icon/AppIcon.iconset` the app icon: macOS PNGs from 16 to 1024 px (`icon_16x16.png` … `icon_512x512@2x.png`). `build.sh` turns it into `Resources/AppIcon.icns` with `tools/make_icon.sh` (`iconutil`, no Xcode needed). To change the icon, replace the PNGs with the same names.
- `docs/` the brief, the screen index, and the user stories, when they exist.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build. The build shows warnings; fix them.
- Unit tests: `tools/test.sh`.
- Self-test (the app's real functions on a /tmp store): `tools/selftest.sh`. Exit 0 when every check passes. Add a check for every story with logic in `SelfTest.swift`.
- After every UI change, take snapshots with sample data and look at them: `tools/snap.sh`.
  It opens the popover from the menu bar and writes `/tmp/TwodayNote-shots/day0-light.png` … `day1-dark.png`, `later-light.png`/`-dark.png`, and `settings-light.png`/`-dark.png`, then quits. `APP_SNAPSHOT_PAGES=day0,settings tools/snap.sh` limits the pages.
  The run takes keyboard focus: anything typed meanwhile lands in the popover.
- Snapshots, seed data, and the self-test refuse to run without `APP_STORE` in /tmp.
- Never test against the real notes in `~/Library/Application Support/TwodayNote/`.
- Then check the grid: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/TwodayNote-shots/*-layout.json`. Both print PASS.
- A change is done when the build has no errors, the grid checks pass, and you looked at the light and dark snapshots.

## Design rules

- Use Apple's controls and system styles. Only the accent color is custom: `UI/Theme.swift` (`ThemeStore.defaultID`). People change it, and light, dark, or system mode (`Prefs.appearance`), in Settings > Giao diện.
- Views use `.tint`, `Palette.accent`, `Palette.accentText` (accent-colored text), and `Palette.onAccent` (text on an accent fill). Never hard-code colors, radii, or durations in views.
- Compare accents: add `APP_ACCENT=<id>` to the snapshot command.
- Spacing comes from `Space` in `UI/Grid.swift`, on a 4 pt grid. Mark custom pages and cards with `.gridArea` and `.gridProbe`.
- Windows open calm: `.noInitialFocus()` on every window and sheet (no focus ring or selected text on open), `.fitsContent()` on sheets and Settings tabs (no scroll bar with nothing to scroll). System scroll bars. Both in `UI/WindowBehavior.swift`.
- Settings: one grouped Form in `SettingsView.swift` (a menu bar app has few settings), opened from ••• > Cài đặt… or ⌘,.
- Window chrome (title bar, popover, menus) stays system. Buttons use system styles, like `.borderedProminent`.
- Colors: `.primary`, `.secondary`, `.tint`, and system colors. Never fixed grays or white for text.
- Every action is in the popover's ••• menu or a block's context menu, and frequent ones have a shortcut (docs/DESIGN.md, Command map).
- `Label` for icon and text pairs. SF Symbols for icons.
- `ContentUnavailableView` for empty states.
- Liquid Glass belongs to floating controls only, never to content.

## Skills

The bama plugin has a skill for each step: `mac-design` (design rules),
`design-system` (accent and tokens), `layout-grid`, `ux-design`,
`swift-swiftui`, `os-integrations`, `performance`, `build-and-verify`,
`test-mac-app`, `app-icon`, `user-stories`, and `improve-loop`. Use them.

## Git

- Commit after each working change, with a message that says what the user can now do.
