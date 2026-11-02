# Architecture

Arrowslit is a SwiftPM macOS app with a small AppKit shell and SwiftUI content. The shell, layout
engine and several surfaces are a GPL-compatible port of Notch Shell; see `NOTICE`.

```
Sources/
├── Arrowslit/main.swift              NSApplication entry point
├── ArrowslitKit/
│   ├── App/                          AppDelegate, AppState, status item, debug hooks
│   ├── Core/                         Pure value types and maths
│   │   ├── NotchAppearance.swift     size, theme, glass and layout controls
│   │   ├── IslandMetrics.swift       Notch Shell size and content constants
│   │   ├── ParityLayout.swift        compact, expanded, elongated and alert sizes
│   │   ├── IslandShape.swift         concave shoulders and slit geometry
│   │   ├── DisplayChoice.swift       built-in, main, pointer, named and all displays
│   │   ├── ScreenGeometry.swift      physical/virtual notch and per-screen geometry
│   │   ├── NotchPresentation.swift   the single “what is showing” resolver
│   │   ├── AgentRequest.swift        six hook formats and OpenCode plugin generator
│   │   ├── UpdateVerification.swift  Ed25519 manifest and image checks
│   │   └── Countdown, ClockFormat, ClipboardHistory, DownloadProgress, LauncherPaging,
│   │       MediaAppFilter, StatsMath, Theme
│   ├── Services/                     System integrations
│   │   ├── TimerService, StopwatchService, CalendarService, RemindersService
│   │   ├── NowPlayingService, LyricsService, AudioHardware
│   │   ├── CallMonitor, MicrophoneMute, CameraAccess
│   │   ├── DownloadsWatcher, DownloadProgressMonitor
│   │   ├── ClipboardService, NotesStore, TodoStore, ShortcutsService, TrayStore
│   │   ├── SportsService and the BigBallsData adapter
│   │   ├── AgentBridge, AgentHookClient
│   │   ├── UpdateService, SettingsStore, SessionLockService
│   │   └── StatsService, SystemMonitorService, KeepAwakeService
│   └── UI/                           SwiftUI views and the borderless panels
│       ├── PanelManager, PanelController, PanelEnvironment
│       ├── ArrowslitRootView         compact, HUD, alert and expanded shell
│       ├── NookView, HomePane, LauncherPane, TrayPane, ClipboardPane
│       ├── SettingsView, SettingsWindowController
│       └── AgentRequestView, CallPane, DownloadPane, NotesPane, NowPlayingPlayerView
└── ArrowslitMedia/                   Optional ObjC media helper, loaded by Perl
```

## Panels and displays

`PanelManager` owns the windows. For a single-display choice it creates one `PanelController`; for
**All displays** it creates one per connected `NSScreen`. Only the active panel accepts the pointer,
keyboard and opened content. The others mirror the compact state and still show alerts.

Each panel carries its own `ScreenGeometry` through the `panelGeometry` environment. A screen with
a camera housing uses the physical notch; a screen without one gets a virtual 160 pt housing at
the top centre. This keeps window frames and SwiftUI surfaces on the same geometry.

`PanelController` owns a borderless, non-activating `NSPanel` above the menu bar. The panel is
hidden at rest, peeks on hover and expands after a short delay. Pointer handling is event-driven:
the hosting view has an `NSTrackingArea`, a global mouse-moved monitor catches approaches to mirror
panels, and one-shot timers exist only while a hover-open or leave-check is pending. A slow
fallback timer is used only when macOS has not granted Accessibility.

`PanelRole` tells a panel whether it is the active one. `ArrowslitRootView` renders
`state.presentation` on the active panel and `state.mirrorPresentation` on mirrors. The active
panel is the only one that can become key; a click in the elongated Home calls `makeKey()` without
activating the whole app, so inline text fields work in the background.

## Alerts and presentations

Calendar reminders and future system events share one path:

```text
CalendarService  ──5 min before──▶  AppState.receive(.upcomingEvent)
                                          │
                                          ▼
                                     AlertQueue
                          one at a time · same-kind coalescing
                          urgency · expiry · pending
                                          │
                                          ▼
                                 PresentationResolver
                       alert > expanded (unless urgent) > compact
                                          │
                                          ▼
                                   NotchAlertView
```

`NotchPresentation` is the single answer to “what is the notch showing?”. `PanelController` and
`ArrowslitRootView` both read it, so the window size and the visible surface cannot disagree.
Alerts wait while the workbench is open unless they are urgent; outside-click and Escape dismiss
the current alert before closing the workbench.

## Layout and Home

`ParityLayout` owns the size contract:

- compact strip: 274 × 32 at Large, 256 × 32 at Small, with the camera housing as the centre gap
- standard nook: 560 × 178
- elongated Home/Tray/Clipboard: up to 1240 × 178, clamped to the screen
- Now Playing: 390 × 218
- call and download panels: 390 × 120
- running timer/stopwatch compact strip: 360 × 124
- compact alerts: 491 × 38; named alerts grow from their ears

Home is adaptive. It shows a 196 pt media card only while something is playing; calendar, timer
and shortcuts share the remaining width with hairline splits. The elongated layout is a horizontal
row of wider widgets: media, calendar, timer, to-dos, Notes and Sports. Tray and Clipboard use
larger cards in the same elongated mode.

`ArrowTheme` owns the warm palette, typography and hairlines. `NotchSurfaceBackground` applies the
Glass/Black surface and the physical notch band; `SlitShape` draws the concave shoulders.

## Now Playing and media

`NowPlayingService` talks to the isolated `ArrowslitMedia` helper and remembers the last useful
source. The compact strip shows artwork and animated bars. Clicking opens the 390 × 218 player with
artwork, title/artist, lyrics, scrubber and transport controls.

Lyrics are optional and off by default. When enabled, only the current song's title, artist, album
and length are sent to lrclib.net; music.163.com is a timed fallback. Answers stay in memory, and a
failed lookup retries on a widening schedule while the song keeps playing.

## Sports

Sports is football-only: a shelf with competition chips and 166 × 92 match cards, an inline
key-events view, follow stars, a pin button and a compact score. `SportsService` owns the snapshot,
detail cache, polling task and daily quota. `SportsRanking` sorts pinned matches first, then
followed teams, followed competitions, live matches and upcoming fixtures.

`BigBallsDataProvider` is the only network adapter. It sends one football
`/v1/matches?sport=football&status=live` request, caches fixtures, and uses a Keychain-stored free
key. Without a key, local `SportsDemoData` supplies preview matches. Goal alerts compare scores
and emit a `SportsGoalEvent`; the same alert shell and haptic are used for the goal card.

## Calls, downloads and system signals

`CallMonitor` uses Core Audio process detection for calls and microphone activity. `CallHangup`
keeps app-specific AppleScript routes for Teams, Zoom, Webex and WhatsApp, with a Show App fallback.
The call panel offers mute and hang-up; it collapses when the call ends.

`DownloadsWatcher` watches the Downloads folder and emits a finished alert. `DownloadProgressMonitor`
listens to Finder's `Progress` reports and also polls Chrome/Firefox partial files
(`.crdownload`, `.part`, `.download`) with a size and rate summary. Reported downloads win over the
same partial filename, so one download never appears twice.

`SystemMonitorService` polls battery, audio and brightness and emits charging, low-battery,
headphone and level HUDs. `SessionLockService` raises the panel above the lock shield when Show on
Lock Screen is enabled. Pure `PowerAlertRules` prevent duplicate low-battery warnings.

## Agent approvals

`AgentBridge` listens on a Unix socket in Application Support with mode `0600` and checks the peer
UID. CLI hooks run Arrowslit's own executable with `--agent-hook`; the client pins the app's
`cdhash` through the peer audit token. OpenCode uses a user-owned JavaScript plugin that listens to
`permission.asked` and `permission.v2.asked` and replies through `client.permission.reply`.

Allow is one-time, Deny is a denial, and Ask returns the request to the assistant. If Arrowslit is
not running or no answer arrives, the hook fails open to the assistant's own prompt. The full
request, command, path or patch is shown with control characters escaped. See
`Docs/Agent-Approval-Security.md`.

## Updates and signing

`UpdateService` asks GitHub's latest-release feed on launch and at most once a day. A release is
accepted only when its page and assets are on approved GitHub hosts.

Signed installs use an Ed25519 envelope over the exact manifest bytes. The manifest pins the
version, bundle identifier, file name, byte size and SHA-256. The updater verifies the signature,
downloads within the size cap, checks the image hash, mounts it, validates the staged bundle's
identifier/version and code signature, then swaps the app atomically and relaunches. If anything
fails, it falls back to opening the DMG.

The app is signed with a stable self-signed `Arrowslit` identity so macOS keeps the same TCC and
Keychain identity across builds. This is not a Developer ID and does not remove Gatekeeper's
warning. See `Docs/Release-Signing.md`.

## Data flow

1. Services publish state with `@Observable`.
2. `AppState` owns the services and the UI state (`isExpanded`, `activeTab`, alerts).
3. `PanelManager` owns one or more `PanelController`s.
4. `ArrowslitRootView` renders the compact strip, HUD, alert, player or workbench.
5. `StatusItemController` provides a menu-bar fallback.
6. `ArrowslitMedia` is a separate process loaded by `/usr/bin/perl`; a media failure cannot take
   down the app.

## Design principles

- **Local first**: no account, analytics or telemetry. Update checks contact GitHub once a day and
  can be turned off; lyrics lookup is optional and off by default.
- **Quiet**: idle CPU near zero; stats only sample while visible; hover is event-driven.
- **Small surface**: one notch, one workbench, no infinite widget grid.
- **Copyleft and attributed**: Notch Shell-derived code stays GPL-3.0-or-later and is credited in
  `NOTICE`. New surfaces should not copy another app's chrome without a compatible license.
- **Failure tolerant**: the media helper can disappear, hooks fail closed, updates never install an
  unverified image.
- **Testable core**: timers, formatting, layout and presentation rules are value types with
  injected clocks.

## Adding a feature

1. Put pure rules in `Core` and test them.
2. Put system access in `Services`, behind a small interface.
3. Add a `WorkbenchTab` and a pane if it needs UI.
4. Update `AppState.select` only when the feature needs lifecycle management.
5. Add a privacy note in Settings.
