# Arrowslit

![Arrowslit](Support/AppIcon-1024.png)

A quiet control surface for the MacBook notch.

Arrowslit is a from-scratch, local-only macOS utility. The notch becomes a narrow
aperture: it stays out of the way until you need it, then opens into a compact
workbench for media, timers, calendar, files, clipboard, notes, reminders and
system stats.

The name comes from the narrow opening in a fortress wall: the smallest aperture
that still gives a defender a full view and full control.

## Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- No account, no analytics, no network

## Download

| | |
| --- | --- |
| **Latest release** | [Arrowslit 0.1.0](https://github.com/j4yop/arrowslit/releases/tag/v0.1.0) |
| **Direct download** | [Arrowslit-0.1.0.dmg](https://github.com/j4yop/arrowslit/releases/download/v0.1.0/Arrowslit-0.1.0.dmg) |
| **SHA-256** | `996cd86d1c860a471cd861cbc454ddb895c7846bca5c428bec91c7414cfc01ab` |
| **Homebrew tap** | [j4yop/homebrew-tap](https://github.com/j4yop/homebrew-tap) |

The DMG is a universal build for Apple Silicon and Intel.

## Install with Homebrew

```bash
brew trust j4yop/tap && brew install --cask j4yop/tap/arrowslit
```

Homebrew 7 asks you to trust a third-party tap once. The cask clears the
quarantine flag after installation, so there is no Gatekeeper detour. Review the
public source and cask before trusting the tap.

On Homebrew versions before 7, this is enough:

```bash
brew install --cask j4yop/tap/arrowslit
```

## Install manually

1. Download [Arrowslit-0.1.0.dmg](https://github.com/j4yop/arrowslit/releases/download/v0.1.0/Arrowslit-0.1.0.dmg).
2. Open the DMG and drag **Arrowslit** into Applications.
3. Open Applications and double-click Arrowslit. macOS will refuse the first
   launch because Arrowslit is not yet notarized. Click **Done**.
4. Open **System Settings → Privacy & Security**, scroll down, and click
   **Open Anyway** next to Arrowslit. Confirm with Touch ID or your password and
   click **Open Anyway** once more.
5. Settings opens automatically. Choose your features, close the window, and
   Arrowslit stays live in the notch.

If you prefer Terminal, after dragging the app into Applications:

```bash
xattr -dr com.apple.quarantine "/Applications/Arrowslit.app"
open "/Applications/Arrowslit.app"
```

Arrowslit is ad-hoc signed for now. A future release can be notarized with an
Apple Developer ID so the manual install no longer needs the extra approval.

## Using it

- Hover the top of the screen for 0.4 seconds, or click the strip, to open.
- Click the slit in the menu bar if the strip is hard to reach.
- Open **Settings** from the menu bar or by reopening Arrowslit to choose which
  features appear in the launcher.
- Close Settings and Arrowslit keeps running in the notch.

## Features

- Now Playing with artwork, progress and transport controls
- Timer, a 25/5 focus session, and Stopwatch
- Calendar and Reminders
- File tray with drag-and-drop and AirDrop
- Clipboard history that skips password-manager items
- Scratchpad, camera mirror, CPU/memory stats
- Keep Awake
- Up to three feature shortcuts beside Home; hold the launcher or use the pencil
  to edit them
- Hover, press, scroll and Reduce Motion polish throughout
- Universal build for Apple Silicon and Intel

## Build

Requires Swift 6 / Xcode 16 or newer (tested with Xcode 26.4.1).

```bash
./Scripts/build-app.sh
open "build/Arrowslit.app"
```

Universal release DMG:

```bash
UNIVERSAL=1 CONFIG=release ./Scripts/build-app.sh
SKIP_BUILD=1 ./Scripts/make-dmg.sh
```

Tests:

```bash
swift test
```

## Permissions

Calendar, Reminders and Camera are managed by macOS and remembered for the
installed copy of Arrowslit. Arrowslit never asks in the background: you press
**Connect** once from Settings or a pane, allow it, and macOS keeps that choice
across quitting and reopening the app. Use one installed copy (the one in
Applications); launching a second copy from the DMG or a duplicate folder makes
macOS treat it as a different app.

Replacing an unnotarized build with a new build can make macOS ask once more.
A notarized release with a stable Developer ID will remove that last prompt
across updates.

## Privacy

Arrowslit has no account, analytics, or network access. Clipboard history, notes,
the file tray and timers stay on this Mac. Camera, Calendars and Reminders are
only requested when you turn those features on.

## Release

- Version 0.1.0 (build 7)
- Universal (`x86_64` + `arm64`)
- Universal DMG: [Arrowslit-0.1.0.dmg](https://github.com/j4yop/arrowslit/releases/download/v0.1.0/Arrowslit-0.1.0.dmg)
- Homebrew cask: [Casks/arrowslit.rb](https://github.com/j4yop/homebrew-tap/blob/main/Casks/arrowslit.rb)

## License

GPL-3.0. See [LICENSE](LICENSE).
