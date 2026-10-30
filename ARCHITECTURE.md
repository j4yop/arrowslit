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

- **Local first**: no account, analytics, telemetry or network.
- **Quiet**: idle CPU near zero; stats only sample while visible.
- **Small surface**: one vertical rail; no infinite widget grid.
- **Original expression**: no copied layouts, strings, icons or animation values from other
  notch apps. Feature ideas are researched; implementation is ours.
- **Failure tolerant**: the media helper can disappear; the rest of the app keeps working.
- **Testable core**: timers, formatting and maths are value types with injected clocks.

## Adding a feature

1. Put pure rules in `Core` and test them.
2. Put system access in `Services`, behind a small interface.
3. Add a `WorkbenchTab` and a pane if it needs UI.
4. Update `AppState.select` only when the feature needs lifecycle management.
5. Add a privacy note in Settings.
