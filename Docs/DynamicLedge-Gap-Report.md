# DynamicLedge 1.4.2 vs Arrowslit 0.9.2 — full gap audit

**Date:** 2 November 2026  
**DynamicLedge:** upstream `shandilyaswagat/dynamic_ledge`, `main` at `10a1dfa` (v1.4.2, 31 Oct 2026)  
**Arrowslit:** local `main` at `6887c9a` (v0.9.2, build 34)  
**Scope:** features, system integrations, accessibility, appearance, shape, sizing, typography, motion, settings, updates and packaging.

> The local `~/code/dynamic_ledge` checkout is **Corbel**, a fork of DynamicLedge 1.4.0. This report uses the upstream 1.4.2 worktree at `/tmp/dl142`, so it includes the 1.4.1/1.4.2 work (new Home, Lyrics, Clipboard search/pins, Download progress, Glass, Agent approvals, stable signing, and scrolling titles).

---

## 1. Executive summary

DynamicLedge is currently a **broader notch operating layer** than Arrowslit. Its biggest advantages are not cosmetic:

1. **Calls and microphone activity** — detects FaceTime/Zoom/Meet/Teams/Webex calls and other mic/camera use, shows call duration, can mute the Mac mic, and can hang up from the notch.
2. **Download progress** — live browser download progress, stop, reveal in Finder, and a finished-download alert.
3. **Coding-assistant approvals** — Allow/Deny Claude Code, Codex, Copilot CLI, Antigravity and Cursor permission requests from the notch, with a security-checked hook.
4. **Multi-display support** — built-in, specific display, follow-the-pointer, or all displays, with a virtual notch on external monitors.
5. **Appearance system** — Small/Medium/Large scaling, custom width/thickness, hidden-at-rest notch with hover peek, Show when idle, click/hover mode and hover delay, Glass theme and pitch-black control.
6. **Elongated layout** — a 1240 pt-wide Home/Tray/Clipboard strip with music scrubbing, calendar, rich notes, wheel timer and a to-do list.
7. **In-app signed updates** — downloads, verifies the code signature, installs and relaunches; a stable self-signed identity keeps permissions across updates.
8. **Keyboard and launcher depth** — ⌃⌥ shortcuts for every tile, paged grid with dots, shortcut labels on tiles, hold-to-edit shortcuts.
9. **Productivity depth** — Clipboard search and pinned clips that survive quitting, rich-text Notes, Shortcuts runner, to-do list, tray links, richer drop preview.
10. **Media depth** — multiple playing apps with a switcher, “Only these apps” media filter, scrolling long titles, paused-media linger.
11. **Notch shape and motion** — concave shoulders, a detached second-activity bubble, hover growth, GPU-animated shape, blur/scale content transitions and a liquid split pulse.
12. **Accessibility depth** — labelled settings toggles, spoken time strings, a VoiceOver “Open Home” action while tucked away, accessibility identifiers, 4 pt hit slop, and labelled icon-only controls.

Arrowslit still leads in a few important places:

- **Sports** — live football scores, Following + Featured, pin-to-notch, goal popup, haptic and quota-aware polling. DynamicLedge has no sports feature.
- **Privacy** — no anonymous usage reporter, no TelemetryDeck, lyrics off by default. DynamicLedge sends a daily anonymous usage signal and turns lyrics on by default.
- **Simplicity** — one fixed layout and a smaller surface, with no agent hooks or call-control Accessibility surface.

The largest practical gaps are **Calls**, **Downloads**, **multi-display**, **appearance/size**, **in-app signed updates**, **labelled Settings controls**, and **keyboard shortcuts**.

---

## 2. Feature matrix

Legend: ✅ present, ⚠️ partial, ❌ missing in Arrowslit, ➕ Arrowslit-only.

### 2.1 Live notch / activities

| Capability | DynamicLedge 1.4.2 | Arrowslit 0.9.2 |
|---|---|---|
| Now Playing with artwork, progress, transport | ✅ | ✅ |
| Lyrics in player and Home | ✅ | ✅ |
| Multiple apps playing + source switcher | ✅ | ❌ single source |
| “Show music from: All apps / Only these apps” filter | ✅ | ❌ |
| Scrolling long song/video titles | ✅ | ❌ truncates |
| Paused-media linger setting | ✅ | ❌ |
| Calls / microphone / camera activity | ✅ | ❌ |
| Call duration, app icon, jump to app | ✅ | ❌ |
| Mac microphone mute from notch | ✅ | ❌ |
| Hang up from notch (Zoom/Teams/Webex/WhatsApp) | ✅ | ❌ |
| Timer and stopwatch | ✅ | ✅ |
| Download progress, stop, Show in Finder | ✅ | ❌ |
| Finished-download alert | ✅ | ❌ |
| Memory/CPU compact Stats activity | ✅ | ❌ panel only |
| Second activity in a detached bubble | ✅ | ❌ |
| Coding-assistant Allow/Deny requests | ✅ | ❌ |
| Sports live scores and goal popup | ❌ | ➕ |
| Power, volume/brightness alerts | ✅ | ✅ |
| Headphone-connected alert | removed in 1.4.2 | ✅ (Arrowslit still has it) |
| Lock Screen timer/music/stopwatch/charging | ✅ private window-server space | ⚠️ timer/music/charging via panel level |

### 2.2 Home and productivity

| Capability | DynamicLedge 1.4.2 | Arrowslit 0.9.2 |
|---|---|---|
| Home live cards for call / mic / music with controls | ✅ | ❌ media card only |
| Adaptive Home sections (live first, then calendar/timer/shortcuts) | ✅ | ❌ fixed media/calendar/timer columns |
| Running timer/stopwatch shown above presets on Home | ✅ | ⚠️ separate clock nudge |
| Calendar month grid + day list | ✅ | ✅ |
| Reminders | ✅ | ✅ |
| Quick timer presets + Focus | ✅ | ✅ |
| Focus/break lengths configurable (15/25/45/50/60, 5/10/15) | ✅ | ❌ fixed 25/5 |
| Favourite Shortcuts on Home | ✅ | ❌ |
| Clipboard search | ✅ | ❌ |
| Pinned clipboard clips that survive quitting | ✅ | ❌ memory only |
| Rich-text Notes (size, bold, italic, underline, colour) | ✅ | ❌ plain TextEditor |
| File Tray with pinned files | ✅ | ✅ |
| Tray links / web shortcuts | ✅ | ❌ file URLs only |
| Tray drop preview of newest files | ✅ | ❌ |
| Document-window drag into Tray | ✅ | ✅ |
| AirDrop | ✅ | ✅ |
| To-do list in elongated Home | ✅ | ❌ |
| Stats four-tile panel | ✅ | ✅ |
| Keep Awake | ✅ | ✅ |
| Mirror with camera off/on | ✅ | ✅ (camera preview closes) |
| Lock Screen | ✅ | ⚠️ |
| First-launch Home preview / greeting | ✅ named welcome | ❌ opens Settings on first launch |

### 2.3 Window, appearance and interaction

| Capability | DynamicLedge 1.4.2 | Arrowslit 0.9.2 |
|---|---|---|
| Hidden at rest, grows only when something happens | ✅ | ❌ compact strip always visible |
| Show when idle | ✅ | ❌ |
| Hover peek + click to open | ✅ | ⚠️ open-on-hover toggle, always visible |
| Choose click vs hover + 0.1–0.5 s delay | ✅ | ❌ fixed ~0.4 s hover, no mode picker |
| Small / Medium / Large size modes | ✅ | ❌ fixed |
| Custom compact width (120–420) and thickness (24–52) | ✅ | ❌ fixed 32 |
| Glass theme + tint slider | ✅ | ❌ |
| Pitch-black toggle | ✅ | ❌ always black |
| Elongated Home/Tray/Clipboard | ✅ | ❌ |
| Standard nook fixed 560×178 | ✅ | ✅ (Home 560×204) |
| Concave shoulders/flare | ✅ 6 compact / 10 expanded | ❌ flat top |
| Bottom radius 30 expanded | ✅ | ⚠️ 18/22 |
| Hover growth (+3 × +2) | ✅ | ❌ |
| Detached second-activity bubble | ✅ | ❌ |
| Content-adaptive alert width/height | ✅ 128/156/96 pt ears, 38 pt high | ❌ fixed 560×86 |
| Virtual notch on external displays | ✅ 180 pt | ❌ built-in display only |
| Display picker: built-in/main/specific/follow pointer/all | ✅ | ❌ |
| Grid 5 columns × 2 rows per page with dots | ✅ | ❌ 6 columns, 12 tiles, no pages |
| Shortcut label on every grid tile | ✅ ⌃⌥M etc. | ❌ |
| Live/on dot on grid tiles | ✅ | ❌ |
| Hold any tile to edit Home shortcuts | ✅ | ⚠️ pencil edit mode |
| Right-click context menu on notch | ✅ | ❌ |
| Swipe music to skip; pull/push notch | ✅ | ❌ |
| Menu bar quick controls | timer, stopwatch, Keep Awake, update, About | ⚠️ open/timer/settings/quit |
| Keyboard shortcuts for every feature | ✅ | ❌ |
| App rename/migration | ✅ 1.4.0 | ❌ |

### 2.4 Updates, signing and permissions

| Capability | DynamicLedge 1.4.2 | Arrowslit 0.9.2 |
|---|---|---|
| Update check | ✅ daily | ✅ launch + daily |
| In-app download + install + relaunch | ✅ | ❌ Download & Open DMG |
| Code-signature verification of update | ✅ | ❌ SHA-256 only |
| Stable signing identity | ✅ own certificate | ❌ ad-hoc signature |
| Permissions survive updates | ✅ | ❌ TCC/Keychain identity resets |
| Update button in open notch | ✅ | ⚠️ alert with Download & Open |
| Homebrew cask | ✅ | ✅ |
| Universal build | ✅ | ✅ |
| Anonymous usage count | ✅ daily TelemetryDeck signal | ❌ none (privacy advantage) |
| Agent hooks write assistant settings | ✅ opt-in | ❌ no hooks |

### 2.5 Engineering / test surface

| Capability | DynamicLedge 1.4.2 | Arrowslit 0.9.2 |
|---|---|---|
| Source size | ~18,300 lines | ~13,600 lines |
| Test files | 20 | 3 |
| Tests covering Glass/Downloads/Agents, media filter, pins/lyrics, layout, presentation, updates, usage, scrolling title | ✅ | ⚠️ core logic + sports; no layout/snapshot/UI tests |
| Pure layout engine tests | ✅ | ⚠️ limited geometry only |
| Accessibility identifiers | 2 | 0 |
| Design spec as code source of truth | ✅ `IslandMetrics` mirrors DESIGN.md | ⚠️ `NotchPanelMetrics` only; many content sizes hard-coded in views |

---

## 3. Detailed gaps

### 3.1 Calls, microphone and hang-up

DynamicLedge’s `CallMonitor` detects microphone and camera use through CoreAudio/CoreMediaIO without a permission prompt. It waits 2 seconds so Siri/dictation do not flash, keeps a 1.5-second grace period, shows the app icon and call duration, and marks known call apps or mic+camera as a call.

It adds:

- **Mute** the Mac microphone from the compact or expanded call view.
- **Hang Up** for Zoom, Teams, Webex and WhatsApp, through app-specific keyboard shortcuts or WhatsApp’s accessible End/Leave call control. Accessibility is requested only after the user presses Hang Up.
- **Show app** when hang-up is not available.
- A camera-in-use indicator and a microphone-use state that is not a call.
- A compact call activity and a 72 pt expanded call panel.

Arrowslit has no call/microphone activity, no mute, no hang-up and no camera-in-use indicator outside Mirror. This is the largest missing live activity.

### 3.2 Download progress

DynamicLedge’s `DownloadProgressMonitor` subscribes to the same `Progress` reports browsers publish for Finder. It:

- Shows a download only after it has run for 1 second, so tiny files do not flash.
- Shows progress, bytes remaining and an estimated time in the compact notch.
- Opens to a 72 pt download view with **Show in Finder** and **Stop** when the browser allows cancellation.
- Emits a finished-download alert with the file, plus a Downloads watcher fallback.
- Is behind the **Finished downloads** setting, off by default because macOS asks for Downloads access.

Arrowslit has no download progress or finished-download alert.

### 3.3 Coding-assistant approvals

DynamicLedge 1.4.2 supports five assistants:

- Claude Code
- Codex
- Copilot CLI
- Antigravity
- Cursor

Each has a Settings switch. Turning one on installs a hook into that assistant’s settings file; turning it off removes it. When the assistant asks for permission, the notch shows the project, tool, short description and the full request; long requests make the panel taller up to eight lines and scroll. **Allow** / **Deny** answers in the assistant’s own format. Closing the panel or waiting 125 seconds falls back to the assistant’s own prompt.

The hook authenticates the peer UID and kernel audit token and checks the hook’s code hash; same-user or same-name processes are not enough. Unsigned/mismatched builds fall back to the assistant’s prompt.

Arrowslit has nothing comparable. This is a high-value developer feature, but it is also the highest-risk integration to copy; it needs its own security review.

### 3.4 Media depth

DynamicLedge has:

- **Multiple sources**: when a second app plays while the first continues, a row of source buttons switches between them; only the system “now playing” app exposes transport controls, other sources offer “Open app”.
- **Media app filter**: All apps, or only the apps the user picked; recent apps are suggested once they play. This keeps browser video and YouTube out of the notch.
- **Scrolling titles**: long song/video titles scroll while playing, stay still when paused or with Reduce Motion.
- **Paused-media linger**: 10/30/60/300 seconds.
- **Lyrics**: timed line in the player and on Home, sliding up as the next line starts.
- **Media switcher height**: 38 pt extra; lyrics add 30 pt to the player.

Arrowslit has single-source Now Playing and timed lyrics, but no source switcher, no app filter, no scrolling title and no linger setting.

### 3.5 Productivity depth

| Feature | DynamicLedge | Arrowslit |
|---|---|---|
| Clipboard search | type-to-filter, Return copies first match, match count | ❌ |
| Pinned clips | up to 20, survive quit, clear leaves pins | ❌ |
| Notes formatting | size, bold, italic, underline, colour, RTF persistence | ❌ plain text |
| Shortcuts runner | favourite Shortcuts on Home, running state | ❌ |
| To-do list | up to 50, Return to add, tick off, delete, persisted | ❌ |
| Tray links | web links kept as draggable shortcuts | ❌ |
| Tray pinned files | yes | ✅ |
| Tray document-window drag | yes | ✅ |
| Drop preview | newest four tray files, 60/40 split | ⚠️ split exists, no file preview |
| Clipboard capacity | 20 | 20 |
| Notes persistence | RTF to preferences | plain text |

### 3.6 Appearance, shape and sizing

DynamicLedge is built around a **shape/layout engine**:

- `NotchAppearance`: width 120–420, height 24–52, size Small/Medium/Large, standard/elongated layout, black/glass theme, glass tint.
- `IslandMetrics`: one source of truth for every dimension; `docs/DESIGN.md` mirrors it.
- `LayoutEngine`: computes compact, alert, nook, expanded, bubble, hover and drop geometry from the current screen and settings.
- `IslandLayout` is `Animatable` with a `SIMD16` vector; the whole shape (pill, radii, flare, bubble, shadow) springs as one value.
- `IslandPath` draws concave shoulders where the shape meets the screen edge.
- A detached circle bubble carries the second activity.
- Hover growth is +3 pt each side, +2 pt down.
- Virtual notch: 180 pt wide, at least 32 pt tall, on external displays.
- Alerts size to content: 128 pt ears normally, 156 pt for named alerts (calendar/shortcut/download), 96 pt for volume/brightness; height is compact + 6 pt.
- Expanded width 390 at Large, 351 at Medium, 312 at Small; nook 560 at Large, 504 at Medium, 448 at Small; elongated up to 1240 pt, 40 pt from screen edges.
- Nook body 120, top inset 10, bottom padding 14, expanded radius 30.
- Launcher body 170, tile 76, gap 10, 5×2 pages.
- Media card 210 wide; rows 30 pt.

Arrowslit has a fixed 560×178 panel, 560×204 Home, 390×218 player, 560×86 alert and 360×124 clock nudge. It has no size modes, custom dimensions, glass, pitch-black toggle, elongated layout, flare, bubble, hover growth, virtual notch or content-adaptive alerts. Its `SlitShape` is a flat-top rounded-bottom rectangle; `NotchPanelMetrics` covers panel sizes but many content sizes are hard-coded inside views.

### 3.7 Multi-display and window behavior

DynamicLedge:

- Keeps the notch on the built-in display by default.
- Can stay on the main display, a specific display (by UUID), follow the pointer, or show on all displays.
- Creates a real virtual notch on displays without a camera housing; it stays retracted until something happens or the pointer rests at the top centre.
- Uses one active panel plus mirror panels; pointer moves between them.
- Hides at rest; peeks on hover; show-when-idle is optional.
- Opens on click or hover with a 0.1–0.5 s delay.

Arrowslit:

- Always uses the built-in display, falling back to the main display when no notch exists.
- Always shows a compact strip with a clock; there is no hidden-at-rest state.
- Has a single panel; no display picker, follow-pointer, all-displays, or virtual notch.
- Has an open-on-hover toggle and fixed ~0.4 s hover, but no click/hover mode picker or delay slider.

### 3.8 Updates, signing and permissions

DynamicLedge 1.4.2:

- Checks GitHub daily.
- Shows an **Update** pill when the notch opens; it shrinks to a round download button beside the grid.
- Downloads the update, verifies its signature, installs and relaunches.
- Signs releases with the app’s own certificate, so Accessibility, Camera, Calendar and other permissions survive updates. 1.4.2 may ask once more because of the signing switch.
- Handles app rename from Dynamic Notch to Dynamic Ledge and keeps settings.

Arrowslit:

- Checks GitHub on launch and daily, with a **Download & Open** alert.
- Verifies SHA-256, opens the DMG and asks the user to drag the app into Applications.
- Is ad-hoc signed; replacing it resets TCC permissions and can trigger the Keychain prompt for the sports key.
- Has no signature verification or stable signing identity.

### 3.9 Accessibility

DynamicLedge has a deliberate accessibility layer:

- **Root action:** `IslandRootView` publishes `.accessibilityAction(named: "Open Home")` while the panel is tucked away, so Voice Control/assistive tools can open Home.
- **Labelled Settings toggles:** `IconToggle` uses `Toggle(isOn:)` with the title and detail as its label; the whole row is one accessible control.
- **Spoken time:** `TimeFormatting.spoken` returns “4 minutes, 59 seconds” for VoiceOver; timer presets use it.
- **Adjustable controls:** timer ruler and wheel expose `accessibilityAdjustableAction`.
- **Labels/values/traits:** tabs, launcher tiles, page dots, stats, download progress, clipboard search, notes, calendar days, reminders, calls, music sources, lyrics, playback position.
- **Identifiers:** `feature-shortcut-editor`, `feature-shortcuts`.
- **Reduce Motion:** shape, content, scrolling title and liquid pulse all check it.
- **Hit slop:** 4 pt around notch/compact shapes.
- **Status item:** system symbol with an accessibility description.
- **Menu/labels:** settings tab icons have accessibility descriptions.

Arrowslit has many good labels (tabs, calendar, timer ruler, player, stats), but these gaps are concrete:

1. **Settings toggles have no accessible name.** `SettingsToggle` and `AlertToggleRow` put the title in a separate `Text` and use `Toggle("", isOn:).labelsHidden()`. VoiceOver sees an unlabelled switch. This affects every toggle in Settings. DynamicLedge’s `Toggle` includes the label.
2. **No root “Open Home” accessibility action.** The compact bar has a label and `.isButton`, but no explicit `accessibilityAction` like DynamicLedge.
3. **No keyboard shortcuts.** DynamicLedge gives every tile a ⌃⌥ shortcut and shows it on the tile; Arrowslit has none.
4. **No spoken time strings.** `ClockFormat` has clock/preset/age, but no VoiceOver-friendly “4 minutes, 59 seconds”.
5. **No accessibility identifiers.** Arrowslit has 0; DynamicLedge has 2.
6. **Some icon-only controls lack labels.** Sports follow star and pin buttons use `.help` but no `.accessibilityLabel`; the menu-bar icon is a custom `NSImage` without `accessibilityDescription`.
7. **No 4 pt hit slop** around compact/interactive shapes; several buttons are 20–24 pt.
8. **No page-dot labels** because there is no pagination.
9. **No Dynamic Type or Increase Contrast handling** — this is shared with DynamicLedge, not a DynamicLedge advantage. Both use fixed macOS point sizes and neither checks `accessibilityDifferentiateWithoutColor` or `accessibilityDisplayShouldIncreaseContrast`.
10. **No accessibility preview/testing surface**; 3 test files, no UI/snapshot tests.

### 3.10 Design tokens, type, colour and motion

DynamicLedge documents and implements:

- **Type:** system SF Pro; compact labels 0.4 × thickness, 11–18 semibold; alerts 14 semibold; expanded title 15; secondary 13 at 55%; timer digits 42 light; progress 11 medium; timer chips 12 semibold. Monospaced digits for changing numbers.
- **Colour:** system dark values — orange `#FF9F0A`, green `#30D158`, red `#FF453A`, yellow `#FFD60A`, blue `#0A84FF`, secondary white 55%, button fill 18%. Album tint from artwork, lifted for black.
- **Motion:** compact spring response 0.42/damping 0.76; alert 0.44/0.74; open 0.48/0.80; hover 0.34/0.72; hide 0.36/0.92; settings 0.30/critical; hover 0.30/0.68. Content swap: old fade+blur 4+scale 0.97 in 0.12 s; new fade+blur 6+scale 0.92→1 in 0.34 s after 0.06 s. Liquid pulse 0→1 in 0.08 s, back to 0 over 0.6 s. Reduce Motion: 0.2 s ease, no liquid.
- **Surface:** pure black default; optional shadow 35% radius 18 y 8 and 0.5 pt 7% outline; Glass theme with smoked/frosted gradient, light bottom lip, `NSVisualEffectView` fallback and macOS 26 Liquid Glass.
- **Shape:** concave shoulders 6/10, bottom radius 30 expanded, bubble, hover growth.

Arrowslit:

- **Type:** fixed 13 semibold title, 11 medium label, 12 regular body, 11 detail, 10 caption; no size modes, no compact scale, no spoken.
- **Colour:** custom amber `#FF9F0A` (same as system orange), softer green `#6BC794`, softer red `#E8665C`, muted 62%, faint 48%, hairline 9%; blue/yellow hard-coded in individual views; no semantic colour set.
- **Motion:** press 0.12 s ease, hover 0.14, quick 0.18, open response 0.34 damping 1.0, close 0.26/1.0, content 0.3/1.0, drop 0.28/1.0; Reduce Motion 0.15 ease. No shape morph, no blur content transition, no liquid pulse. The panel animates its window frame instead of an animatable shape.
- **Surface:** flat black, hairline border; no glass/material, no shadow/outline controls.
- **Shape:** `SlitShape` flat top, bottom radius 12/18/22; no shoulders, bubble or hover growth.
- **Design system:** `NotchPanelMetrics` only; many content sizes live in views (`HomePane` 196/156/148, `SportsPane` 166×92, `LauncherPane` 6 columns, etc.). DynamicLedge has a single `IslandMetrics`/`DESIGN.md` contract.

---

## 4. Exact size comparison (Large)

| Element | DynamicLedge 1.4.2 | Arrowslit 0.9.2 |
|---|---|---|
| Size modes | Small 0.8 / Medium 0.9 / Large 1.0 | none |
| Compact height | `max(thickness, notch height)`; thickness 24–52 | 32 |
| Compact ear | `max(0.8 × slot, slot + (width−180)/2)`, slot = round(h×1.15) | `(compactWidth − notchWidth)/2`; compactWidth 320–420 |
| Expanded music width | 390 / 351 / 312 | 390 |
| Expanded music content height | 140 + 30 lyrics + 38 source switcher | 218 total fixed |
| Nook width | 560 / 504 / 448 | 560 |
| Nook body | 120 | 120-ish (Home total 204) |
| Nook total height at 32 notch | 178 | 178 (Home 204) |
| Launcher | 560×228; body 170; tile 76; gap 10; 5×2 pages | 560×178; 6×2, no pages; tiles smaller |
| Elongated | up to 1240 wide, 40 pt edges | none |
| Alert | 38 high; ears 128/156/96 | 560×86 fixed |
| Clock nudge | no separate nudge; timer content 76 | 360×124 |
| Settings | 520×552–600, 5 toolbar tabs | 540×620, one scrolling page |
| Expanded radius | 30 | 18/22 |
| Shoulders | 6 compact / 10 expanded | none |
| Virtual notch | 180 wide × max(menu bar, 32) | housing 160 wide (not a selectable virtual notch) |
| Hit slop | 4 pt | none |
| Hover growth | +3 × +2 | none |
| Media card | 210 | 196×132 |
| Home rows | 30 | 132 card / columns |

---

## 5. Where Arrowslit leads

- **Sports**: live Premier League/La Liga/UCL/Serie A/Bundesliga/Ligue 1 scores, Following + Featured, pin-to-notch, inline goals/cards, goal popup with haptic and animation, free-tier quota handling.
- **Privacy**: no telemetry/usage reporter; lyrics optional and off by default; no coding-assistant hook files; local-only by default.
- **Goal feedback**: the goal popup/haptic is unique to Arrowslit.
- **Smaller surface**: no agent-hook security surface, no call Accessibility automation, no private Lock Screen window-server dependency.
- **Simple fixed layout**: one Home/panel size and a flat visual language; fewer layout states to test.

---

## 6. Prioritized roadmap

### P0 — parity foundations

1. **Calls/microphone activity** (compact + expanded, app icon, duration, mute, hang up, camera indicator).
2. **Appearance engine**: size modes, custom width/thickness, hidden-at-rest + show-when-idle, click/hover + delay, display picker, virtual notch, shoulders/bubble, content-adaptive alerts.
3. **Settings accessibility**: labelled toggles, spoken time strings, root “Open Home” action, icon-only labels, 4 pt hit slop, accessibility identifiers.
4. **In-app updates + stable signing**: self-signed certificate, signature verification, install/relaunch, permission-preserving updates.
5. **Keyboard shortcuts** (⌃⌥ per feature) and shortcut labels on launcher tiles.

### P1 — daily-use depth

6. **Download progress + finished download**.
7. **Clipboard search + pinned clips**.
8. **Rich-text Notes**.
9. **Shortcuts runner** on Home.
10. **Media app filter, multi-source switcher, scrolling titles, paused linger**.
11. **Grid pagination + page dots + live dots + hold-to-edit**.
12. **Tray links + newest-file drop preview**.
13. **Compact Stats activity** and **second-activity bubble**.

### P2 — delight and parity

14. **Elongated layout** with music scrubber, calendar strip, rich notes, wheel timer, to-do list.
15. **Glass theme + pitch-black/custom surface controls**.
16. **Coding-assistant approvals** (only with a dedicated security review).
17. **Right-click menu, swipe gestures, menu-bar quick controls**.
18. **First-launch welcome / Home preview**.
19. **App rename/migration** and **anonymous usage** (do not add usage without a privacy decision).

---

## 7. What not to copy blindly

- **TelemetryDeck usage reporter**: DynamicLedge sends a daily anonymous signal; Arrowslit’s no-telemetry position is a strength. Keep it off unless the product explicitly decides otherwise.
- **Agent approvals**: useful, but it writes hooks into other apps’ settings and authenticates peer processes. It needs its own threat model and tests; do not ship a rough version.
- **Dead DynamicLedge code**: `FileConverter`, `AudioOutputService`, `PerAppEQEngine` and `AudioSpectrum` exist in the 1.4.2 tree but have no UI/`IslandModel` references. They are not shipped features; do not count them in parity.
- **Removed headphone alert**: DynamicLedge removed it in 1.4.2 because macOS already shows it; Arrowslit still has it. This is a parity difference, not necessarily a missing feature.
- **Private Lock Screen window-server calls**: DynamicLedge guards availability; copying it adds fragility across macOS updates.
- **Always-hidden notch**: Arrowslit’s persistent clock is a deliberate identity. Hiding it by default would be a product change, not a pure feature add.

---

## 8. Sources

- DynamicLedge upstream: `shandilyaswagat/dynamic_ledge` at `10a1dfa` (v1.4.2), especially:
  - `docs/DESIGN.md`
  - `Sources/NotchKit/Core/IslandMetrics.swift`
  - `Sources/NotchKit/Core/IslandLayout.swift`
  - `Sources/NotchKit/Core/NotchAppearance.swift`
  - `Sources/NotchKit/Settings/SettingsStore.swift`
  - `Sources/NotchKit/Settings/SettingsViews.swift`
  - `Sources/NotchKit/Core/LauncherItem.swift`
  - `Sources/NotchKit/Core/Presentation.swift`
  - `Sources/NotchKit/Views/HomeSections.swift`
  - `Sources/NotchKit/Views/LauncherViews.swift`
  - `Sources/NotchKit/Views/ExpandedViews.swift`
  - `Sources/NotchKit/Views/GlassSurface.swift`
  - `Sources/NotchKit/Views/Theme.swift`
  - `Sources/NotchKit/Views/IslandRootView.swift`
  - `Sources/NotchKit/Services/CallMonitor.swift`
  - `Sources/NotchKit/Services/DownloadProgressMonitor.swift`
  - `Sources/NotchKit/Core/AgentRequest.swift`
  - `Sources/NotchKit/Services/AgentBridge.swift`
  - `Sources/NotchKit/Core/TimeFormatting.swift`
  - `CHANGELOG.md` 1.4.0–1.4.2
- Arrowslit: `main` at `6887c9a` (v0.9.2), especially:
  - `Sources/ArrowslitKit/Core/NotchPanelMetrics.swift`
  - `Sources/ArrowslitKit/Core/Theme.swift`
  - `Sources/ArrowslitKit/Core/ScreenGeometry.swift`
  - `Sources/ArrowslitKit/UI/DesignSystem.swift`
  - `Sources/ArrowslitKit/UI/NookView.swift`
  - `Sources/ArrowslitKit/UI/HomePane.swift`
  - `Sources/ArrowslitKit/UI/LauncherPane.swift`
  - `Sources/ArrowslitKit/UI/SettingsView.swift`
  - `Sources/ArrowslitKit/Services/SettingsStore.swift`
  - `Sources/ArrowslitKit/App/AppState.swift`
  - `README.md` / `ARCHITECTURE.md`
