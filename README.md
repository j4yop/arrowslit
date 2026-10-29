# Arrowslit

A quiet control surface for the MacBook notch.

Arrowslit is a from-scratch, local-only macOS utility. The notch becomes a narrow aperture:
it stays out of the way until you need it, then opens into a compact workbench for timers,
clipboard, notes and system stats.

The name comes from the narrow opening in a fortress wall: the smallest aperture that still
gives a defender a full view and full control.

## Status

Early build. The first milestone is a small, fast core:

- Menu-bar app, no Dock icon
- Notch-fused compact strip
- Expanded workbench with a vertical feature rail
- Timer, clipboard history, scratchpad and CPU/memory stats
- Local only: no account, no analytics, no network

Calendar, Now Playing, file tray, mirror and multi-display support are next.

## Build

Requires Swift 6 / Xcode 16 or newer (tested with Xcode 26.4.1).

```bash
./Scripts/build-app.sh
open "build/Arrowslit.app"
```

For a debug build:

```bash
CONFIG=debug ./Scripts/build-app.sh
```

## Tests

```bash
swift test
```

## License

GPL-3.0. See [LICENSE](LICENSE).
