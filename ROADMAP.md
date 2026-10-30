# Arrowslit roadmap

The goal is a quiet, fast, local-only notch utility — not a clone of any existing app. The
feature set is inspired by the best free notch projects, but the interaction model, visual
language and code are our own.

## What exists today (0.4.3)

- Menu-bar accessory, no Dock icon
- Notch-fused compact strip with timer status
- Expanded workbench: vertical feature rail, header, footer
- Countdown timer with presets, pause/resume/reset
- Calendar next event with EventKit permission flow
- Five-minute calendar heads-up with Join buttons for Meet, Zoom, Teams and Webex
- One-alert-at-a-time notch notifications with expiry, urgency and dismissal
- Media-aware default: opening the notch shows the player when music/video is playing, otherwise Home
- Full 390×218 Now Playing player with lyrics
- Apple Music-style 306×146 nudge in the Home media card
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

## Phase 1 — daily driver polish

- **Multiple displays**: virtual notch on external screens, display picker, follow pointer.
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
