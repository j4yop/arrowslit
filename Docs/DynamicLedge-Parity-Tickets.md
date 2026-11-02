# Arrowslit × Notch Shell — parity tickets

**Spec:** `Docs/Notch Shell-Parity-Spec.md`  
**Baseline:** Arrowslit `0.9.2` (`6887c9a`), Notch Shell `1.4.2` (`10a1dfa`)  
**Working rule:** one ticket per fresh context; TDD at the ticket's public seam; `code-review` before merge.

## Progress

**2 November 2026 — tickets 02, 04 and the first half of 06 are in.**

- `NotchAppearance`, `IslandMetrics`, `ParityLayout` and `IslandShape` are in the library.
- The compact strip uses Notch Shell's ear math: 274×32 at Large, 256×32 at Small.
- Concave shoulders, the 30 pt expanded radius and the 16 pt alert radius are live.
- The Glass surface is wired to the Appearance theme.
- Settings has a working Appearance section for layout, theme, glass tint, pitch black, size, width, thickness and reset.
- The notch is hidden at rest (199×35 hover target), peeks on hover, expands after the hover delay, and collapses when the pointer leaves.
- **Show when idle** keeps the clock pill visible instead.
- Home is now the real **560×178** nook, with the media card reduced to fit the 120 pt body.
- Home is adaptive: media only takes a section while something is playing; otherwise calendar and timer share the full width with the hairline split.
- Calendar, download, update and welcome alerts use Notch Shell's **491×38** camera-gap row; goal and timer-done cards keep their larger layout.
- The launcher is now **5×2 pages** with two-page paging, page dots, live dots on tiles and hold-to-edit.
- `LauncherPaging` is a pure core rule with four tests.
- The **elongated layout** is live: Home, Tray and Clipboard stretch to **1240×178**, with a horizontal Home row for calendar, timer, notes and Sports. Launcher and activity panels keep their standard widths.
- Settings is now the **five-tab shell**: General, Appearance, Activities, Home and About, with a 520×640 window, per-tab window titles and system-blue controls.
- Every Settings switch now has an accessible name. The AX dump confirms descriptions like “Show when idle, Keep a small clock pill visible…”.
- The hidden notch has an “Open Home” accessibility action and a click target.
- Timer running values are spoken as “4 minutes, 59 seconds”.
- **Calls & Microphone** is live: Core Audio process detection, microphone use, camera use, compact call ear, 390×120 call panel, mute, hang-up routes for Teams/Zoom/Webex/WhatsApp, and Show App fallback. A real mic stream produced the activity; mute and auto-collapse were verified.
- **Downloads** is live: `DownloadProgressMonitor`, `DownloadsWatcher`, 40%-style compact percent, 390×120 download panel with Show in Finder / Stop, finished-download alert, and an off-by-default Settings toggle. Chrome-style `.crdownload`/`.part` folder fallback is implemented, deduplicated against browser `Progress` reports, and verified live with a real 2.1 MB partial file and a finished rename alert.
- **Media depth** is live: remembered multi-source switcher, “All apps / Only these apps” filter with app icons and an Add App picker, Core Animation scrolling titles, and the 10/30/60/300 paused-media linger picker. The source switcher, “Now / Spotify” selected state and Open App fallback were verified visually.
- **Clipboard search and pins** is live: persistent pinned clips, pin/unpin controls in both clipboard views, search with match count and Return-to-copy, Clear that preserves pins, and keyboard focus for the search field. Three clips, filtering, pinning, clear and relaunch persistence were verified live.
- **Rich Notes** is live: RTF persistence, bold/italic/underline/colour/size toolbar, formatting kept across launches, and plain-text migration.
- **To-dos** are live in the elongated Home: persisted list, add/complete/delete, open-first ordering, and the elongated Home keyboard pre-focus path. A real click into the inline field made the panel key (`typing=true`, field editor active), and Return added the task.
- **Shortcuts runner** is live: service, favourite-shortcut settings with a four-item limit, Home shortcuts section, running state and finished/failed notch alert.
- **Tray links** are live: http(s) drags and an Add link dialog, link icons and Open Link actions, pinned links persisting by URL.
- **Drop preview** is live: the Tray side of the drop target shows the newest four items.
- **Compact Stats** is live: CPU and memory ears when Stats is enabled and nothing else is live.
- **Second-activity bubble** is live: a detached 26 pt circle for the secondary activity, with the compact shape kept centred on the camera.
- **Settings 09 is complete:** native `Form(.grouped)` sections, five-tab shell, system-blue controls, 4 pt hit slop on small controls, and labels for the remaining icon-only buttons (Sports refresh/pin/follow, dialogs, calls, downloads, launcher).
- **Coding-assistant approvals** are live for **Claude Code, Codex, Copilot CLI, Antigravity, Cursor and OpenCode**: per-assistant hooks/plugin install and uninstall, urgent approval panel with full request, Allow/Deny/Ask, 125-second fallback, user-only socket and CLI code-hash authentication. See `Docs/Agent-Approval-Security.md`.
- **Multi-display support** is implemented: Built-in, Main, named display, Follow the pointer and **All displays**, plus a virtual notch on screens without a camera housing. All displays creates one panel per screen; only the active panel takes the pointer, keyboard and opened content, while every screen still gets alerts. Per-panel geometry is carried through the views instead of a process-wide screen.
- **Elongated Tray and Clipboard** now use a real wide treatment: larger file/clip cards, a horizontal empty state and an Add files action, while the standard nook keeps its compact cards.
- **Signed in-place updates** are implemented: Ed25519 manifest verification, size/hash/bundle checks, staged app validation, atomic swap and relaunch, plus the release/sign scripts. A local 0.10.0 DMG and signed manifest were produced. See `Docs/Release-Signing.md`.
- **Stable code signing** is implemented with a dedicated self-signed `Arrowslit` identity in `~/Library/Keychains/arrowslit-signing.keychain-db`; `Scripts/setup-signing.sh` creates it and release builds use it. The designated requirement is pinned to that certificate, so future builds keep the same macOS permission identity. It is self-signed, not a Developer ID, so Gatekeeper still warns.
- Debug builds now use a separate Keychain service, so rebuilding never prompts for the release BigBallsData key.
- **The parity harness is live:** `Scripts/parity.sh` drives compact, home, elongated, launcher, tray, clipboard, HUD, goal, player and agent states, checks panel sizes, and compares the shape/alpha mask against `Docs/Images/Parity-Golden`. See `Docs/Parity/README.md`.
- **Multi-display was verified on a real virtual second screen:** two panels appeared, pointer handoff moved the expanded panel between them, Follow the pointer moved the panel to the virtual screen and back, and the charging HUD mirrored on both.
- **Pointer handling is event-driven:** the hosting view's tracking area and a global mouse-moved monitor replace the fixed 0.12 s timer; one-shot timers exist only during a pending hover-open or leave check. A slow fallback is used only without Accessibility.
- **Real assistant evidence:** OpenCode 2.2.5's `permission.ask` plugin hook returned `allow`, `deny` and `ask` for the real Arrowslit alert, and the Claude/Codex hook binary returned each format. Claude Code is not logged in for headless use, Codex exec forces approval off, and Copilot/Cursor/Antigravity are not installed here.
- **Signed upgrade:** installed 0.10.0 over 0.9.2, then installed a second same-certificate build over it. Camera, Calendar and Accessibility survived; the existing Sports Keychain item asks for its one-time “Always Allow”.
- **Released 0.10.0:** PR #26 was merged into `main` at `1aaaaf0`. The signed `0.10.0` app was published as Latest and the Homebrew cask was updated.
- **Released 0.10.1:** PR #27 was merged into `main` at `4fa7c84`. The signed `0.10.1` DMG, checksum and update manifest are public at `v0.10.1` (Latest), the Homebrew cask PR #2 was merged, and `brew upgrade --cask arrowslit` installed 0.10.1 on this Mac.
- **0.10.1 is the feel/finish pass:** Notch Shell's exact palette and type scale, the persistent Home/Files/Clipboard header, the 580 pt nook geometry, the paged launcher with real ⌃⌥ labels, click/hover mode and hover delay, scaled Small/Medium content, the corrected Clipboard/Tray cards, conditional player lyrics and the 580×178 Calendar/Timer/Stats/Notes pages.
- **162 tests pass in 47 suites.**

Remaining for release: real-assistant approval QA for all six (hooks are deliberately not installed in the user's live configs), a real TCC permission-survival run with the stable certificate, final migration/release QA, and the Path A attribution policy decision.

---

## How to work this plan

1. **Approve the spec and the Path A/Path B decision.** Nothing starts until ticket 00 records the licensing/policy choice.
2. **Work the frontier.** A ticket can start only when every ticket in its "Blocked by" list is done. The graph is deliberately wide after the shell lands: calls, downloads, media, productivity and agent approvals can run in parallel.
3. **One fresh context per ticket.** Each ticket is sized to fit one context window. Read the spec, the ticket, and the named upstream modules; do not carry the whole port in one session.
4. **Red → green → review.** Write the failing behavioural test at the ticket's seam, make it pass, then run the `code-review` skill against the branch.
5. **Every ticket ends demoable.** Build the app, run the acceptance checks, and attach a screenshot or a short recording for visual tickets.
6. **Integration branch.** Work tickets on `parity/dl-1.4.2`; merge each ticket only when its acceptance criteria pass. `main` stays on 0.9.x until the final release ticket.

## Dependency graph

```
00 Policy + baseline
└── 01 Parity harness
    └── 02 Shape, metrics and motion
        ├── 03 Appearance and sizing controls
        ├── 04 Presentation and alerts
        └── 05 Display and window behaviour
            └── 06 Home, tabs, compact and expanded content
                ├── 07 Launcher and pages
                ├── 08 Elongated layout
                └── 09 Settings shell and accessibility
                    ├── 10 Calls and microphone
                    ├── 11 Downloads
                    ├── 12 Media depth
                    ├── 13 Clipboard search and pins
                    ├── 14 Notes, Shortcuts and to-dos
                    ├── 15 Tray links, drop preview, compact Stats and bubble
                    └── 16 Agent approvals
17 Signed updates (starts after 00; release-gated by 18)
18 QA, migration and release
```

## Ticket index

| # | Ticket | Size | Blocked by |
|---|---|---|---|
| 00 | Policy, attribution and baseline | S | None |
| 01 | Parity harness and reference captures | M | 00 |
| 02 | Shape, metrics and motion engine | L | 01 |
| 03 | Appearance and sizing controls | M | 02 |
| 04 | Presentation, alerts and compact states | L | 02 |
| 05 | Display and window behaviour | L | 02 |
| 06 | Home, tabs, compact and expanded content | L | 04, 05 |
| 07 | Launcher, pages and shortcut editing | M | 06 |
| 08 | Elongated layout | M | 06 |
| 09 | Settings shell and accessibility | L | 03, 05, 06 |
| 10 | Calls and microphone | L | 06, 09 |
| 11 | Download progress | M | 06, 09 |
| 12 | Media depth | M | 06, 09 |
| 13 | Clipboard search and pins | M | 06, 09 |
| 14 | Rich Notes, Shortcuts runner and to-dos | L | 06, 09 |
| 15 | Tray links, drop preview, compact Stats and bubble | M | 06, 09 |
| 16 | Coding-assistant approvals | L | 06, 09 |
| 17 | Signed in-place updates | L | 00 |
| 18 | QA, migration and release | L | 03–17 |

---

## 00 — Policy, attribution and baseline

**What to build:** a recorded decision on Path A (direct GPL port) or Path B (clean-room), plus the repository state needed to start safely.

**Blocked by:** None.

**Work**

- Choose Path A or Path B and write the choice into `Docs/Notch Shell-Parity-Spec.md`.
- Path A only: add `NOTICE` naming Swagat Shandilya and contributors, the upstream URL, commit `10a1dfa`, and GPL-3.0.
- Path A only: update `CONTRIBUTING.md`, `ROADMAP.md` and `ARCHITECTURE.md` so they no longer claim all code/UI is original or that the project can be dual-licensed without upstream permission.
- Create `parity/dl-1.4.2` from `main`; tag/freeze `v0.9.2`.
- Add a short `Docs/Parity/README.md` with the comparison source, screenshot location and build command.

**Acceptance**

- [x] The Path A/B decision is recorded (Path A).
- [x] If Path A: `NOTICE` exists and the policy documents are honest.
- [x] `swift test` and `./Scripts/build-app.sh` pass on the parity branch.
- [ ] The 0.9.2 release remains reproducible from its tag.

---

## 01 — Parity harness and reference captures

**What to build:** a repeatable way to compare Arrowslit's notch against Notch Shell at fixed states, so "1:1" is measured.

**Blocked by:** 00.

**Work**

- Add a parity harness (test target or debug-only command) that renders the notch root at a fixed size and state to PNG.
- Capture Notch Shell references at 2× for: hidden, idle, compact (music, timer, call, download, sports), expanded (music, timer, call, download, agent), nook (Home, Tray, Clipboard, Notes, Mirror, Timers, Calendar, Reminders, Stats, Launcher), alerts (wide, named, level, agent), standard/elongated, Small/Medium/Large, Black/Glass.
- Store references under `Docs/Parity/Reference/`; document how to recapture.
- Add a diff script with a small tolerance and a manual-review flag for Glass.
- Add a debug hook to drive presentation states without waiting for real events.

**Acceptance**

- [x] The harness renders every state in the matrix on the live debug panel.
- [x] A diff report names the state, size, theme and maximum channel delta.
- [ ] The reference set is reproducible from the 1.4.2 DMG (manual 1.4.2 captures exist; the golden set is an Arrowslit regression baseline).
- [x] Glass states are marked manual-review rather than failing on backdrop differences.

---

## 02 — Shape, metrics and motion engine

**What to build:** the Notch Shell shape and layout foundation, replacing Arrowslit's fixed panel geometry.

**Blocked by:** 01.

**Work**

- Port the size contract: compact height, ear width, expanded width, nook width, elongated width, alert ears, window margin, screen edge inset, hover growth, hit slop, virtual notch.
- Port the animatable layout value: pill, radii, flare, opacity, bubble, shadow, stroke, content rect, camera gap, strip height, content scale, notch band.
- Port the outline with flat top, concave shoulders and rounded bottom.
- Port the motion curves and content transitions, including the Glass variants.
- Replace `SlitShape` / `NotchPanelMetrics` usage in the compact, Home, player, alert and clock surfaces.
- Add `NotchAppearance` with width 120–420, thickness 24–52, size scale 0.8/0.9/1.0, standard/elongated, black/glass, glass tint, pitch black, clamping and defaults.

**Acceptance**

- [ ] Geometry tests cover every size, width/thickness clamp, virtual notch and alert-ear case.
- [ ] The shape has concave shoulders, 30 pt expanded radius and hover growth.
- [ ] A compact shape at Large/Black matches the reference within tolerance.
- [ ] Small and Medium scale content without clipping.
- [ ] Reduce Motion uses a short ease and no liquid pulse.
- [ ] No view hard-codes a panel size that belongs in the metrics contract.

---

## 03 — Appearance and sizing controls

**What to build:** the Appearance settings that drive ticket 02, including live preview.

**Blocked by:** 02.

**Work**

- Add Home layout (Standard/Elongated), Theme (Black/Glass), Glass tint, Pitch black, Size, Width, Thickness and Restore Defaults.
- Keep the shape visible while the Appearance tab is open, as Notch Shell does.
- Persist every value and migrate existing Arrowslit installations to sensible defaults.
- Add the settings copy/footers that explain what each control does.

**Acceptance**

- [ ] Every control changes the notch immediately and survives relaunch.
- [ ] Restore Defaults returns to Notch Shell's standard appearance.
- [ ] Invalid or out-of-range persisted values are clamped, not crashed.
- [ ] Existing users keep a usable notch after upgrade.
- [ ] Appearance screenshots match the 1.4.2 reference.

---

## 04 — Presentation, alerts and compact states

**What to build:** the state machine that decides what the notch shows, including hidden, idle, compact, expanded, nook, alert and drop.

**Blocked by:** 02.

**Work**

- Port the presentation resolver and its priority rules.
- Add hidden-at-rest, hover peek, idle, compact primary/secondary, expanded activity, nook tab and drop target.
- Add content-adaptive alert sizing: 38 pt high; 128/156/96 pt ears.
- Add alert queueing, urgency, expiry, same-kind coalescing and outside-click dismissal.
- Add the second-activity bubble and the liquid split pulse.
- Add the sports activity/alert cases without changing the shell's priority rules.

**Acceptance**

- [ ] Presentation tests cover every state and precedence combination.
- [ ] Hidden-at-rest is the default; Show when idle and preview override it.
- [ ] Alerts size to content and never clip a named alert.
- [ ] A second activity produces a detached bubble, not a wider pill.
- [ ] Sports goal alerts use the same alert shell and remain dismissible.
- [ ] Screenshot parity for compact, expanded and alert states.

---

## 05 — Display and window behaviour

**What to build:** multi-display support and the window/pointer behaviour that makes the shell feel native.

**Blocked by:** 02.

**Work**

- Add Display: Built-in, Main, named display, Follow the pointer, All displays.
- Add the virtual notch on displays without a camera housing, hidden until an activity or hover.
- Add one active window plus mirror windows for All displays.
- Route pointer, drag/drop, keyboard focus and gestures to the active display only.
- Add click vs hover opening and the 0.1–0.5 s hover delay.
- Add collapse on pointer exit, outside-click dismissal and Escape.
- Add pull-to-open/push-to-close and swipe-to-skip/pull-to-switch gestures.
- Keep the panel above the menu bar, across Spaces and full-screen apps.

**Acceptance**

- [x] Built-in, external and All displays work without windows jumping under the pointer.
- [ ] A named display survives reconnecting by UUID (not tested with a reconnect).
- [x] The virtual notch stays hidden until needed and reveals on hover.
- [x] Notes and Clipboard search can take the keyboard and hand it back.
- [x] A file drag from Finder reaches the correct Tray/AirDrop zone.
- [x] No fixed pointer polling happens when the pointer is far from the notch.

---

## 06 — Home, tabs, compact and expanded content

**What to build:** the Notch Shell Home surface and the shared compact/expanded view family, with Arrowslit's features plugged in.

**Blocked by:** 04, 05.

**Work**

- Port the tab header, back-button panels, Home sections and adaptive three-section layout.
- Port the media card, calendar row, timer row, shortcuts section and live cards.
- Port compact views for music, timer, call, download, stats and sports.
- Port expanded views for music, timer, call, download and agent requests.
- Add Sports as a Home tab and Keep Awake as a launcher/panel feature.
- Keep Arrowslit's clock, calendar, stats and sports content, but restyle them with the parity tokens.

**Acceptance**

- [ ] Home lays out 0–3 sections without overlap or scrolling.
- [ ] The media card opens the player; the calendar row opens the calendar.
- [ ] A running timer and stopwatch appear above the presets.
- [ ] Sports fits the Home tab and the compact notch without breaking the shell.
- [ ] All compact/expanded screenshots match the reference within tolerance.
- [ ] No text is clipped at Small size or with long titles.

---

## 07 — Launcher, pages and shortcut editing

**What to build:** the 5×2 paged launcher with page dots, live dots and hold-to-edit shortcuts.

**Blocked by:** 06.

**Work**

- Port the launcher grid: 5 columns, 2 rows per page, 76 pt tiles, 10 pt gap.
- Add page dots, live/on dots and the back/Home relationship.
- Add Sports and Keep Awake tiles.
- Add hold-to-edit for the shortcuts beside Home, with add/remove and Done.
- **Do not** add ⌃⌥ shortcuts or shortcut labels.

**Acceptance**

- [ ] 13 tiles produce two pages, with the second page sized correctly.
- [ ] Page dots reflect the current page and are labelled for VoiceOver.
- [ ] Holding a tile enters edit mode; Done exits and persists.
- [ ] Disabled features are hidden from the grid and from the shortcut choices.
- [ ] No keyboard-shortcut UI or labels exist.

---

## 08 — Elongated layout

**What to build:** the wide, short Home/Tray/Clipboard layout.

**Blocked by:** 06.

**Work**

- Port the elongated Home width, edge inset, horizontal widget row and scrolling behaviour.
- Add the music scrubber, calendar strip, rich notes, wheel timer and to-do list.
- Keep the same content model as standard Home; only the layout changes.
- Respect the display's usable width and the 1240 pt maximum.

**Acceptance**

- [ ] Elongated Home spans the top of the screen without touching the edges.
- [ ] Widgets scroll sideways without stealing the notch's vertical gestures.
- [ ] Notes and to-dos can take the keyboard only after a click.
- [ ] Switching back to Standard preserves content and settings.
- [ ] Screenshot parity at 1240 pt and at the minimum width.

---

## 09 — Settings shell and accessibility

**What to build:** the five-tab Settings window, all parity settings, and the accessibility layer.

**Blocked by:** 03, 05, 06.

**Work**

- Replace the one-page settings with General, Appearance, Activities, Home and About tabs.
- Port `Form(.grouped)`, `IconToggle`, `LabeledContent`, section footers and the 520 pt width.
- Add every Notch Shell setting except keyboard shortcuts; add the Arrowslit Sports section.
- Fix toggle labels: the row title must be the `Toggle` label, not a separate `Text` plus `Toggle("")`.
- Add the root "Open Home" action, spoken time strings, identifiers, hit slop and icon labels.
- Add About's version, update control, Source Code and License links.
- Migrate 0.9.2 defaults into the new keys.

**Acceptance**

- [ ] Every tab matches the 1.4.2 reference layout and grouping.
- [ ] Every switch has a non-empty accessible name; the AX audit passes.
- [ ] VoiceOver can open Home while the notch is hidden.
- [ ] Timer values are spoken in words.
- [ ] Sports settings remain reachable and understandable.
- [ ] Existing settings survive the migration.
- [ ] No `Toggle("").labelsHidden()` remains in a labelled settings row.

---

## 10 — Calls and microphone

**What to build:** call/microphone activity, mute and hang-up.

**Blocked by:** 06, 09.

**Work**

- Port call detection for FaceTime, Zoom, Meet, Teams, Webex and generic mic/camera use.
- Show app icon, duration, camera use and mic state.
- Add mute via the default input device, restoring volume on quit.
- Add hang-up for Zoom/Teams/Webex/WhatsApp, with "Show app" fallback.
- Request Accessibility only when Hang Up is pressed.
- Add the Calls & Microphone setting.

**Acceptance**

- [ ] Detection matrix passes for the named apps and generic mic use.
- [ ] Siri/dictation does not flash a call.
- [ ] Mute works and is restored when the app quits.
- [ ] Hang Up works where supported; fallback never traps the user.
- [ ] No Accessibility prompt appears until Hang Up is used.
- [ ] Call compact/expanded screenshots match the reference.

---

## 11 — Download progress

**What to build:** live download progress, stop/reveal and finished-download alert.

**Blocked by:** 06, 09.

**Work**

- Port browser `Progress` observation and the Downloads-folder fallback.
- Show a download only after it has run for one second.
- Add compact progress, expanded 72 pt view, bytes remaining, ETA and file name.
- Add Show in Finder, Stop (when cancellable) and the finished alert.
- Add the Finished downloads setting, off by default.

**Acceptance**

- [ ] Safari and Chrome downloads appear with progress.
- [ ] A tiny file does not flash the notch.
- [ ] Stop and Show in Finder work; Stop is hidden when the browser cannot cancel.
- [ ] The finished alert appears once and names the file.
- [ ] The feature is off until the user enables it and grants Downloads access.

---

## 12 — Media depth

**What to build:** multiple media sources, app filtering, scrolling titles and paused-media linger.

**Blocked by:** 06, 09.

**Work**

- Port the multi-source media model and source switcher.
- Add "Show music from: All apps / Only these apps" with app icons and Add App.
- Add scrolling titles that pause when paused and respect Reduce Motion.
- Add paused-media linger choices 10/30/60/300 seconds.
- Keep lyrics and the existing Arrowslit lyrics privacy behaviour.

**Acceptance**

- [ ] Two playing apps produce a source switcher; the active source shows transport controls.
- [ ] The app filter excludes browsers when chosen.
- [ ] Long titles scroll only while playing.
- [ ] Paused media disappears after the chosen linger.
- [ ] Lyrics still work and remain off by default for Arrowslit upgrades.

---

## 13 — Clipboard search and pins

**What to build:** searchable clipboard history with persistent pins.

**Blocked by:** 06, 09.

**Work**

- Port clipboard search: type to filter, Return copies the first match, show match count.
- Add pinned clips (up to 20) that survive quitting; Clear leaves pins.
- Keep password-manager markers skipped.
- Add the search bar to the compact and elongated Clipboard views.
- Label the search field, results and pin buttons for VoiceOver.

**Acceptance**

- [ ] Search filters in real time and Return copies the first result.
- [ ] Pinned clips survive relaunch; unpinned clips do not.
- [ ] Clear removes unpinned clips only.
- [ ] Passwords are still skipped.
- [ ] The Clipboard view takes the keyboard only while searching.

---

## 14 — Rich Notes, Shortcuts runner and to-dos

**What to build:** the remaining Home productivity depth.

**Blocked by:** 06, 09.

**Work**

- Replace the plain notes editor with rich text: size, bold, italic, underline, colour, RTF persistence.
- Add the Shortcuts runner: favourite shortcuts on Home, running state and result alert.
- Add the to-do list: up to 50, Return to add, tick off, delete, persisted.
- Add the settings toggles and empty states.
- Keep text editing keyboard handling correct in standard and elongated layouts.

**Acceptance**

- [ ] Rich text round-trips through quit/relaunch.
- [ ] Favourite Shortcuts run from Home and report success/failure.
- [ ] To-dos add, complete, delete and persist.
- [ ] Notes and to-dos do not steal keyboard focus until clicked.
- [ ] Empty states are clear and accessible.

---

## 15 — Tray links, drop preview, compact Stats and bubble

**What to build:** the remaining file/status depth.

**Blocked by:** 06, 09.

**Work**

- Add web links to the tray as draggable shortcuts.
- Add the newest-file drop preview with the 60/40 split.
- Add compact CPU/memory Stats beside the camera when nothing else is active.
- Add the second-activity bubble if not already delivered by ticket 04.
- Keep pinned files and document-window dragging working.

**Acceptance**

- [ ] Web links can be dropped, stored, dragged out and opened.
- [ ] Dragging files over the notch previews the newest tray files.
- [ ] Compact Stats appears only when nothing else is active and stops when hidden.
- [ ] The second-activity bubble shows the secondary activity without overlap.
- [ ] Pinned files survive quit; unpinned files clear.

---

## 16 — Coding-assistant approvals

**What to build:** Allow/Deny requests from Claude Code, Codex, Copilot CLI, Antigravity and Cursor.

**Blocked by:** 06, 09. **Security review is a hard gate.**

**Work**

- Write the threat model first: socket location/permissions, peer UID, audit token, hook code hash, replay, timeout, denial-of-service and prompt-injection risks.
- Port the request model, bridge, hook client and per-assistant hook settings.
- Add install/uninstall that preserves existing JSON and removes only our hook.
- Show project, tool, short description and the full request; expand to eight lines and scroll.
- Add Allow/Deny, 125-second timeout and fallback to the assistant's prompt.
- Add per-assistant settings with the exact file path.

**Acceptance**

- [ ] A forged same-UID/same-name peer is rejected.
- [ ] A modified hook binary is rejected.
- [ ] Allow/Deny answers in each assistant's format.
- [ ] Closing the panel or timing out falls back cleanly.
- [ ] Uninstall leaves the assistant's settings valid and otherwise unchanged.
- [ ] The security review signs off before the feature is enabled by default.

---

## 17 — Signed in-place updates

**What to build:** download, verify, install and relaunch, with permissions surviving updates.

**Blocked by:** 00.

**Work**

- Create and document a stable Arrowslit code-signing certificate.
- Create an Ed25519 release key; embed the public key in `Info.plist`.
- Sign a manifest containing version, bundle ID, size and SHA-256.
- Port bounded download, manifest verification, checksum, bundle/version check and code-signature validation.
- Implement atomic swap with rollback and relaunch.
- Update `Scripts/release.sh`, `make-dmg.sh`, the cask and the README.
- Handle the one-time migration from ad-hoc 0.9.2 (permissions may reset once).

**Acceptance**

- [x] A bad signature, wrong bundle ID, wrong version and oversized asset are rejected.
- [ ] A valid update installs and relaunches from inside the app (manual signed installs were tested; the in-app network path has not).
- [ ] Accessibility, Camera, Calendar and the Sports Keychain item survive the next update (Accessibility/Camera/Calendar survived; Keychain needs its one-time Always Allow).
- [ ] A failed swap restores the old app.
- [x] Homebrew cask points at the same signed build and `brew fetch` verifies it.
- [x] The release notes and README describe the signing change.

---

## 18 — QA, migration and release

**What to build:** the release candidate and the evidence that parity is real.

**Blocked by:** 03–17.

**Work**

- Run the full manual matrix: calls, downloads, five assistants, multi-display, virtual notch, all appearance combinations, elongated, gestures, keyboard focus.
- Run the accessibility audit with VoiceOver and Accessibility Inspector.
- Run performance checks: idle CPU, memory over 24 hours, no polling when hidden, no layout work far from the notch.
- Test upgrade paths: 0.9.2 → 0.10.0, 0.9.x settings migration, Keychain and TCC survival, Homebrew upgrade.
- Update `README.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `CONTRIBUTING.md`, `NOTICE` and the cask.
- Tag and publish the release; keep the 0.9.2 tag reproducible.

**Acceptance**

- [ ] Every ticket's acceptance criteria pass on the release build.
- [ ] The screenshot diff is clean or manually signed off for every state.
- [ ] VoiceOver can name and operate every Settings control and every notch action.
- [ ] No P0 regression in Sports, timer, calendar, clipboard, tray, notes or updates.
- [x] The release is signed, checksummed, published and installable via Homebrew.
- [x] The GPL source and NOTICE are present in the release.
