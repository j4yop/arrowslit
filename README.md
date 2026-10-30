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

## Install with Homebrew

```bash
brew trust j4yop/tap && brew install --cask j4yop/tap/arrowslit
```

Homebrew 7 asks you to trust a third-party tap once. The cask clears the
quarantine flag after installation, so there is no Gatekeeper detour. Review the
public source and cask before trusting the tap.

## Install manually

1. Download `Arrowslit-0.1.0.dmg` from
   [Releases](https://github.com/j4yop/arrowslit/releases).
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

## Privacy

Arrowslit has no account, analytics, or network access. Clipboard history, notes,
the file tray and timers stay on this Mac. Camera, Calendars and Reminders are
only requested when you turn those features on.

## License

GPL-3.0. See [LICENSE](LICENSE).
