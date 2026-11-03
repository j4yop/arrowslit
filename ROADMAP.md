# Arrowslit roadmap

Arrowslit is a quiet, fast, local-only notch utility. See `NOTICE` and `LICENSE` for license terms.

## What shipped in 0.9.2

- Menu-bar accessory, no Dock icon
- Notch-fused compact strip with timer status
- Expanded workbench: vertical feature rail, header, footer
- Shared Timer/Pomodoro/Stopwatch clock panel with a sliding minute ruler and haptic detents
- Three-column Home with lyric media card, calendar event and timer quick actions
- Four-tile Stats panel and month-grid Calendar
- File Tray drop zone and pinned files
- Football shelf with Premier League, La Liga, Champions League, Serie A, Bundesliga and Ligue 1, Following + Featured, and a 32px notch score
- BigBallsData Free adapter with Keychain key storage and quota-aware refresh
- Narrow running timer/stopwatch HUD with pause and close
- Calendar next event with EventKit permission flow
- Five-minute calendar heads-up with Join buttons for Meet, Zoom, Teams and Webex
- One-alert-at-a-time notch notifications with expiry, urgency and dismissal
- Media-aware default: opening the notch shows the player when music/video is playing, otherwise Home
- Daily GitHub update check, checksum-verified DMG download and Download & Open button
- Rate-limit-safe latest-release check through the GitHub releases redirect
- Full 390×218 Now Playing player with lyrics
- Apple Music-style 306×146 card in the Home media card
- Expand affordance on the Home media card that opens the tall player (artwork/title also clickable)
- Liquid animations and haptic feedback controls
- Optional lock-screen notch with timer, media and charging
- Power, headphone and volume/brightness alerts in a compact icon-and-level HUD
- Smooth volume/brightness fill animation and pulsing charging/low-battery icons
- Launch update check and a once-per-version Update available notch prompt with Download & Open
- Bluetooth headphone volume fallback for devices that expose volume on channel 1/2
- Optional timed lyrics, off by default
- File tray (drop targets, file picker, Quick Look icons)
- Camera mirror with explicit permission
- Now Playing via an optional system media helper
- Clipboard history (20 text items, memory only, private markers skipped)
- Scratchpad saved in UserDefaults
- CPU / memory monitor
- Settings window, launch at login, menu-bar icon toggle
- App icon, ad-hoc signed app bundle and DMG
- Swift Testing coverage for pure logic

## What changed in 0.10.0

- Appearance engine, presentation rules, Home, launcher, alerts and elongated layout
- Multi-display: Built-in, Main, Follow the pointer, named display and All displays, plus the virtual notch
- Calls/microphone, downloads, media depth, clipboard search/pins, Rich Notes, inline to-dos and Shortcuts
- Six coding-assistant approval adapters, including OpenCode
- Signed in-place updates with an Ed25519 manifest and a stable self-signed permission identity
- Browser partial-download fallback, wide Tray/Clipboard layouts and event-driven hover

## Phase 1 — daily driver polish

- ~~**Multiple displays**: virtual notch on external screens, display picker, follow pointer.~~
- **Keyboard**: global hotkey to open, Escape/arrow navigation, quick timer shortcuts.
- **Timer polish**: notifications, sound choice, repeat, custom minutes.
- **Clipboard polish**: search, pin, source app icons.
- **Notes polish**: rich text or Markdown preview, export.
- **Files polish**: drag out, Quick Look preview, session restore (opt-in).
- **Settings polish**: per-feature toggles, reset, diagnostics.
- **Accessibility**: full labels, reduce motion, keyboard-only operation.

## Phase 2 — files and camera

- File tray (session-only references, drag in/out, QuickLook, clear on quit)
- AirDrop from the tray
- Mirror (camera preview with explicit permission, camera off when hidden)
- Downloads heads-up
- Window-drag capture (Accessibility, opt-in)

## Phase 3 — presence

- Call/microphone activity (Core Audio)
- Camera-in-use indicator
- Charging / low battery
- Bluetooth headphone connection
- Volume / brightness indicators
- Lock-screen display (opt-in, private APIs)

## Phase 4 — platform

- A small widget/extension API so the community can add modules
- Themes / density / typography
- Localization
- Signed updates with an Ed25519 manifest
- Homebrew cask, notarized build
- Documentation site and contributor guide

## Quality bar

- Idle CPU near zero; no polling when nothing is visible
- No network unless the user explicitly checks for updates
- No account, no analytics, no telemetry
- Every feature has a clear privacy note
- Tests for pure logic; manual QA for system integration
- No copied code, assets or UI text from other notch apps
