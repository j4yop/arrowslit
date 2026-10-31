# Architecture

Arrowslit is a SwiftPM macOS app with a small AppKit shell and SwiftUI content.

```
Sources/
├── Arrowslit/main.swift          NSApplication entry point
├── ArrowslitKit/
│   ├── App/                      AppDelegate, AppState, status item, debug hooks
│   ├── Core/                     Pure value types and maths
│   │   ├── Countdown.swift
│   │   ├── ClockFormat.swift
│   │   ├── ClipboardRules.swift
│   │   ├── ScreenGeometry.swift
│   │   ├── StatsMath.swift
│   │   └── Theme.swift
│   ├── Services/                 System integrations
│   │   ├── TimerService
│   │   ├── ClipboardService
│   │   ├── NotesStore
│   │   ├── StatsService
│   │   ├── CalendarService
│   │   ├── TrayStore
│   │   └── NowPlayingService
│   └── UI/                       SwiftUI views and the borderless panel
└── ArrowslitMedia/               Optional ObjC media helper, loaded by Perl
```

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

## Now Playing nudge

The compact strip shows album art on the left and four animated bars on the right. Clicking it
opens `NowPlayingPlayerView`, the 390 × 218 expanded player: 56 pt artwork, title/artist,
waveform, optional lyric line, white scrubber and back/pause/forward controls.

Home uses the same visual language in a fixed **306 × 146** nudge card on the left. The Home
panel is **560 × 204** only on the Home tab so that card keeps the nudge geometry; every other
tab stays 560 × 178. Home uses the blue nudge scrubber and times, while the tall player uses the
inline white scrubber.

`NotchPanelMetrics` owns the compact, Home, player and alert sizes. `PanelController` uses the
same value for the window frame, so the visible surface and window cannot disagree. Album
artwork is tinted on the media reader's background queue and the bars animate with Core
Animation, keeping both off the main render path.

Lyrics are optional and off by default. When enabled, `LyricsService` sends only the song's
title, artist, album and length to lrclib.net. If lrclib is unavailable or has no timed result,
it asks music.163.com for a timed fallback and requires the title, artist and length to match.
The answer stays in memory. A failed lookup is retried on a widening schedule (5s, 15s, 60s,
then every 5 minutes) while the same song keeps playing.

## Clock panel

`ClockPane` is one shared Timer / Pomodoro / Stopwatch surface. `SlidingRuler` draws a
minute tape at 14 pt per minute with 3.5 x 34 pt ticks, labels every fifth minute, faded
viewport edges and a fixed triangle pointer. Dragging follows the pointer as a fractional
minute and settles on a whole minute with a spring; a click jumps to the tapped tick.
`RulerMath` owns the clamp, drag, click and visible-range maths. `ClockPane` fires one
alignment haptic per minute when Haptics are enabled.

While a timer or stopwatch runs, `NotchPresentation.clockRunning` replaces the 560 x 178 setup
panel with the 360 x 124 running nudge: back, pause/resume, close, and the label/time. The
compact strip also shows the running timer or stopwatch and opens that nudge on click.

## System signals

`SystemMonitorService` polls the internal battery through IOKit, the default audio device and
volume through CoreAudio (main element, then channel 1/2 for Bluetooth devices), and display brightness through the DisplayServices symbol. It emits
the existing `NotchAlert` cases for charging, low battery, Bluetooth headphones and the
volume/brightness HUD. The first reading is a baseline, so launching the app does not replay an
old alert. Pure `PowerAlertRules` keep the 20% and 10% warnings from firing twice.

System alerts use a compact `NotchPresentation.hud` instead of the larger alert panel. The
compact strip keeps its 32 pt frame and swaps its content for an icon on the left and a live
level bar or short status on the right. Volume/brightness fills animate; charging and low-battery
icons pulse unless Liquid animations or Reduce Motion is off. Calendar and timer alerts keep the
560 x 86 panel.

`SessionLockService` listens for the screen lock/unlock and screen-saver notifications. When the
user enables Show on Lock Screen, `PanelController` raises the panel above the shielding window
and keeps it in the compact presentation; otherwise the panel is ordered out while locked. The
panel ignores mouse events while locked.

## Updates

`UpdateService` asks GitHub's latest-release feed on launch and at most once a day after that (and
on demand) for a newer semantic version. A new version is announced once in the notch with an
Update available alert and a Download & Open action; the Settings row remains the manual path.
A release is accepted only when its page and assets are on approved GitHub hosts. The Settings ›
Updates row shows the version, a **Download & Open** button, download progress and errors.

The button downloads the DMG to Downloads, verifies the published SHA-256 when available, then
opens the image. Installing remains deliberate: the user drags Arrowslit into Applications. The
app never replaces itself, and the update check can be disabled in Settings.

## Data flow

1. Services publish state with `@Observable`.
2. `AppState` owns the services and the small amount of UI state (`isExpanded`, `activeTab`).
3. `ArrowslitRootView` renders either the compact strip or the workbench.
4. `PanelController` owns a non-activating `NSPanel`, resizes it between the compact and
   expanded shapes, and keeps it above the menu bar.
5. `StatusItemController` provides a menu-bar fallback; it observes the menu-bar setting.
6. `ArrowslitMedia` is a separate process loaded by `/usr/bin/perl`. It talks JSON over pipes,
   so a media failure cannot take down the app.

## Design principles

- **Local first**: no account, analytics or telemetry. Update checks contact GitHub once a day and can be turned off; lyrics lookup is optional and off by default.
- **Quiet**: idle CPU near zero; stats only sample while visible.
- **Small surface**: one vertical rail; no infinite widget grid.
- **Original expression**: no third-party source, assets, strings or icons are copied. Visual
  behavior is researched and independently implemented in Arrowslit.
- **Failure tolerant**: the media helper can disappear; the rest of the app keeps working.
- **Testable core**: timers, formatting and maths are value types with injected clocks.

## Adding a feature

1. Put pure rules in `Core` and test them.
2. Put system access in `Services`, behind a small interface.
3. Add a `WorkbenchTab` and a pane if it needs UI.
4. Update `AppState.select` only when the feature needs lifecycle management.
5. Add a privacy note in Settings.
