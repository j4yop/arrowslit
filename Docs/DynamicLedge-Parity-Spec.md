# Arrowslit × Notch Shell — parity spec

**Status:** proposed; not started  
**Baseline:** Arrowslit `0.9.2` (`6887c9a`), Notch Shell `1.4.2` (`10a1dfa`, build 78)  
**Comparison source:** upstream `shandilyaswagat/arrowslit`, run from the 1.4.2 release DMG  
**Scope owner:** Jay Gopal  
**Related:** `Docs/Notch Shell-Gap-Report.md`, `Docs/Notch Shell-Settings-Gap-Report.md`

---

## Problem Statement

Arrowslit is a focused, local-first notch utility. Notch Shell is a broader notch operating layer: calls and microphone control, download progress, coding-assistant approvals, multi-display and virtual-notch support, a full appearance/sizing engine, signed in-place updates, deeper media and productivity features, and a much more complete accessibility layer.

The gap is not a handful of buttons. Notch Shell is built around a different shell: an animatable shape/layout engine, a hidden-at-rest presentation model, a 5×2 paged launcher, adaptive Home sections, a five-tab Settings window, and a native `Form`-based settings surface. Arrowslit's fixed 560×204 / 560×178 panels and custom one-page Settings cannot reach 1:1 parity by adding controls to the existing views.

The user wants Arrowslit to match Notch Shell's look, animation, colour, behaviour and working model, while keeping Arrowslit's unique Sports feature and excluding Notch Shell's keyboard-shortcut feature.

## Solution

Replace Arrowslit's notch shell with a GPL-compatible port of Notch Shell's shell, then re-integrate Arrowslit's services and Sports feature into that shell.

The port is delivered as vertical slices: each slice leaves a buildable, demoable app and is tested at a public seam. The end state is a pixel-parity notch shell, a five-tab Settings window, calls/microphone, downloads, agent approvals, multi-display, appearance/sizing, media depth, productivity depth, signed updates, and a full accessibility layer.

## Decision Required: derivation and the repo's "original expression" policy

Arrowslit is GPL-3.0. Notch Shell is GPL-3.0. Copying and adapting Notch Shell source is **license-compatible** provided Arrowslit preserves copyright notices, ships the complete corresponding source, and remains GPL-3.0.

However, `CONTRIBUTING.md`, `ROADMAP.md` and `ARCHITECTURE.md` currently say:

- "Do not copy code, comments, assets or UI text from another notch app."
- "No third-party source, assets, strings or icons are copied."
- "The goal is to keep the codebase original."
- Contributions require a CLA with copyright assignment "to keep the project dual-licensable."

A 1:1 port contradicts all four statements. There are two honest paths:

### Path A — direct GPL port (recommended for exactness)

- Copy/adapt the Notch Shell modules listed below.
- Add a `NOTICE` file naming Swagat Shandilya and contributors, the upstream repository, the commit, and GPL-3.0.
- Update `CONTRIBUTING.md`, `ROADMAP.md` and `ARCHITECTURE.md` to describe Arrowslit as a GPL-3.0 derivative work, not an original-expression project.
- Drop the dual-licensing claim unless the Notch Shell authors grant permission.
- Keep Arrowslit's branding, icon, Sports feature and privacy choices.

**Result:** fastest path to true 1:1; legally clean; loses the "original expression" and dual-license claims.

### Path B — clean-room visual parity

- Do not copy Notch Shell source, comments, assets or strings.
- Reimplement the same behaviour and measurements from a written behavioural spec, screenshots and black-box observation.
- Keep Arrowslit's original code and dual-license option.

**Result:** can match the visible result closely, but costs substantially more, cannot guarantee byte-for-byte animation timing, and still carries similarity risk if the implementation is too literal.

**Recommendation:** choose Path A if "1:1 exact" is the priority; choose Path B if the "original expression" promise matters more than exactness. The rest of this spec assumes **Path A**, with the policy change as ticket 00.

**Decision (2 November 2026): Path A.** Arrowslit is GPL-3.0-or-later and its `NOTICE`, `CONTRIBUTING.md`, `ROADMAP.md` and `ARCHITECTURE.md` now record the Notch Shell attribution.

---

## User Stories

1. As a MacBook user, I want the notch to stay hidden when nothing is happening, so that it does not distract me.
2. As a MacBook user, I want a small peek when I hover the notch, so that I know it is there without opening it.
3. As a MacBook user, I want to choose click-to-open or hover-to-open, so that the notch matches how I work.
4. As a MacBook user, I want to set the hover delay, so that the notch does not open when my pointer merely crosses it.
5. As a MacBook user, I want the notch to stay open when I am using it and collapse when my pointer leaves, so that it behaves predictably.
6. As a MacBook user, I want Small, Medium and Large size modes, so that the notch fits my screen and eyesight.
7. As a MacBook user, I want to fine-tune the compact width and thickness, so that the closed shape matches my display.
8. As a MacBook user, I want a pitch-black surface, so that the extension is indistinguishable from the physical notch.
9. As a MacBook user, I want a Glass theme with a tint slider, so that the open notch feels like smoked glass instead of a black slab.
10. As a MacBook user, I want the shape to have concave shoulders, a detached second-activity bubble and hover growth, so that it looks like the iPhone's Dynamic Island rather than a rounded rectangle.
11. As a MacBook user, I want the notch on the built-in display, the main display, a named display, the display under my pointer, or every display, so that it follows my setup.
12. As an external-monitor user, I want a virtual notch at the top centre of a display without a camera housing, so that I get the same experience everywhere.
13. As a multi-display user, I want activities and alerts on every screen but opened content only on the screen I am using, so that nothing jumps under my pointer.
14. As a user with a long song title, I want the title to scroll while playing, so that I can read all of it.
15. As a user with several media apps, I want to switch between them, so that the notch shows the one I care about.
16. As a user who does not want browser video in the notch, I want to allow only chosen media apps, so that YouTube and other sites stay out.
17. As a user who pauses music, I want it to linger for 10, 30, 60 or 300 seconds, so that the notch does not vanish instantly.
18. As a person on a call, I want the notch to show the call app, duration, camera use and a microphone indicator, so that I know what is using my mic.
19. As a person on a call, I want to mute the Mac microphone from the notch, so that I do not have to find the app's mute button.
20. As a person on a Zoom, Teams, Webex or WhatsApp call, I want to hang up from the notch, so that I can end the call without switching apps.
21. As a person whose app cannot be hung up automatically, I want a "Show app" fallback, so that I am never stuck.
22. As a person downloading a file, I want to see progress, bytes remaining and an estimated time in the notch, so that I know when it will finish.
23. As a person downloading a file, I want to reveal it in Finder or stop it from the notch, so that I stay in control.
24. As a person downloading a file, I want a finished-download alert, so that I notice when it lands.
25. As a developer using Claude Code, I want Allow/Deny permission requests in the notch, so that I do not have to switch to the terminal.
26. As a developer using Codex, Copilot CLI, Antigravity or Cursor, I want the same approval flow, so that every assistant behaves consistently.
27. As a security-conscious user, I want the approval hook to authenticate the peer process and the hook binary, so that another local process cannot approve commands on my behalf.
28. As a security-conscious user, I want closing the approval or waiting two minutes to fall back to the assistant's own prompt, so that a lost notch never blocks my work.
29. As a clipboard user, I want to search my history, so that I can find an old clip quickly.
30. As a clipboard user, I want to pin clips that survive quitting, so that important text is always available.
31. As a note-taker, I want bold, italic, underline, colour and text size, so that my scratchpad is more than plain text.
32. As a Shortcuts user, I want my favourite shortcuts on Home, so that I can run them without opening the app.
33. As a task user, I want a small to-do list in the elongated Home, so that I can tick things off from the notch.
34. As a file-tray user, I want to keep web links as draggable shortcuts, so that the tray is useful beyond local files.
35. As a file-tray user, I want a preview of the newest files when I drag something over the notch, so that I can see where it will land.
36. As a performance-minded user, I want compact CPU and memory beside the camera when nothing else is happening, so that I can glance at system load.
37. As a multi-activity user, I want a second activity in a detached bubble, so that music and a timer can coexist.
38. As a launcher user, I want a 5×2 paged grid with page dots and live dots, so that I can reach every feature without a cramped 6-column grid.
39. As a launcher user, I want to hold a tile to edit the shortcuts beside Home, so that customisation is direct.
40. As a Settings user, I want General, Appearance, Activities, Home and About tabs, so that settings are grouped like a system app.
41. As a VoiceOver user, I want every Settings switch to have an accessible name, so that I know what I am changing.
42. As a VoiceOver user, I want a spoken "Open Home" action while the notch is tucked away, so that I can open it without a mouse.
43. As a VoiceOver user, I want timer values spoken as "4 minutes, 59 seconds", so that I do not have to decode "4:59".
44. As a keyboard-only user, I want focus rings, labelled icon buttons and a 4 pt hit slop, so that controls are reachable and forgiving.
45. As a user who reduces motion, I want every shape, content and scrolling animation to respect Reduce Motion, so that the app does not make me ill.
46. As a user updating the app, I want it to download, verify, install and relaunch from inside the app, so that I do not have to drag a DMG.
47. As a user updating the app, I want my Accessibility, Camera, Calendar and Keychain permissions to survive, so that I do not have to re-grant everything.
48. As a security-conscious user, I want the updater to verify a signed manifest and the app's code signature, so that a compromised release feed cannot install arbitrary code.
49. As a privacy-conscious user, I want no telemetry, so that my usage stays on my Mac.
50. As a football fan, I want Arrowslit's live Sports shelf, pinned match, goal popup and haptic to keep working inside the new shell, so that parity does not cost me the feature I use.
51. As a football fan, I want the compact score to remain in the notch, so that I can glance at the match without opening anything.
52. As a user with an existing install, I want my settings, clipboard pins, tray pins, notes, followed teams and Sports key to survive the upgrade, so that parity does not reset my setup.
53. As a user who does not want keyboard shortcuts, I want no ⌃⌥ tile shortcuts or shortcut labels, so that the feature set matches my request.
54. As a maintainer, I want a NOTICE and clear GPL attribution if we port Notch Shell code, so that the project is legally clean.
55. As a maintainer, I want one screenshot-parity harness, so that "1:1" is measured rather than argued about.

---

## Implementation Decisions

### 1. Replace the shell; do not decorate the old one

The port targets Notch Shell's shell architecture:

- `LayoutEngine` / `IslandLayout` / `IslandPath` for geometry.
- `NotchAppearance` for width, thickness, size, layout, theme and glass tint.
- `IslandMetrics` as the single size contract.
- `PresentationResolver` / `IslandPresentation` for hidden, idle, compact, expanded, nook, alert and drop states.
- `IslandWindowManager` / `IslandWindowController` for display choice, virtual notch, pointer routing, drag/drop, gestures and keyboard focus.
- `IslandRootView` and the Home/Launcher/Expanded view family.
- A five-tab Settings window built with `Form(.grouped)`.

Arrowslit's `NotchPanelMetrics`, `ScreenGeometry`, `SlitShape`, `PanelController` and one-page `SettingsView` are retired or reduced to compatibility shims. Keeping two layout systems would guarantee drift.

### 2. Model mapping

A new parity model owns the shell state; Arrowslit's services remain the source of feature truth.

| Notch Shell concept | Arrowslit mapping |
|---|---|
| `IslandModel` | `NotchModel` (new), owns presentation, expand target, hover, drag, alerts, display context |
| `SettingsStore` | `SettingsStore` extended with appearance, display, calls, downloads, agents, media, productivity keys |
| `ActivityKind` | `.call`, `.timer`, `.stopwatch`, `.nowPlaying`, `.download`, `.stats`, plus `.sports` |
| `HomeTab` | `.home`, `.tray`, `.clipboard`, `.notes`, `.mirror`, `.timers`, `.calendar`, `.reminders`, `.stats`, `.launcher`, plus `.sports`, `.keepAwake` |
| `LauncherItem` | same cases plus `.sports`, `.keepAwake`; **no keyboard shortcut labels** |
| `IslandAlert` | same cases plus `.sportsGoal(SportsGoalEvent)` |
| `IslandPresentation` | same cases; Sports is an activity and a nook tab |
| `AppState` | thin compatibility facade over `NotchModel` + services during migration |

`ActivityKind.priority` becomes: call, timer, stopwatch, sports, nowPlaying, download, stats. Sports sits above media so a live score is not hidden by music; this is an Arrowslit-specific ordering decision.

### 3. Sports stays first-class

Sports is not a Notch Shell feature and must not be lost in the port.

- Add a `Sports` tile to the launcher and a `Sports` tab to Home.
- Keep the compact score, pinned match, Following + Featured, goal detection, goal popup and haptic.
- Add `.sportsGoal` to the alert model and a Sports goal view that matches the new alert shell.
- Keep BigBallsData key storage, quota handling and the 250-request/day guard.
- Put Sports settings in the Activities tab (or a sixth tab if the user prefers). The default plan is a **Sports section inside Activities**, preserving Notch Shell's five-tab shape.

### 4. Settings shape

- Five tabs: General, Appearance, Activities, Home, About.
- `SettingsTabViewController` with toolbar-style tabs and a 520 pt width.
- Native `Form(.grouped)` sections, `IconToggle` rows, `LabeledContent`, `Picker`, `Slider` and footers.
- Replace Arrowslit's custom `SettingsSection` cards and amber toggles with Notch Shell's system-blue/native controls.
- Keep an Arrowslit-specific Sports section; keep the BigBallsData quota footer.
- No keyboard-shortcut toggle, because the feature is excluded by request.

### 5. Accessibility is part of the shell, not a cleanup pass

- Every `Toggle` owns its label; never `Toggle("").labelsHidden()` in a row that visually names the control.
- Add a root `.accessibilityAction(named: "Open Home")` while hidden/compact.
- Add spoken time strings for timers, presets and countdowns.
- Add accessibility identifiers for the shortcut editor, launcher grid, settings tabs and parity-critical controls.
- Add 4 pt hit slop around compact shapes and icon-only buttons.
- Label the status item, Sports follow/pin buttons, media source buttons, page dots, stats and download progress.
- Respect Reduce Motion in the shape, content, scrolling title and liquid pulse.

### 6. Security boundaries

- **Calls:** detection uses CoreAudio/CoreMediaIO without a prompt; mute uses the default input device; hang-up requests Accessibility only after the user presses Hang Up.
- **Agent approvals:** Unix socket in a user-only directory, peer UID + audit token + hook code hash, 125-second timeout, assistant-format Allow/Deny, clean uninstall. This ships only after a dedicated security review.
- **Updates:** Ed25519-signed manifest, bounded downloads, SHA-256, bundle ID/version check, code-signature validation, atomic swap and rollback.

### 7. Licensing

Path A requires:

- `NOTICE` naming the upstream project, authors, commit and GPL-3.0.
- Updated `CONTRIBUTING.md`, `ROADMAP.md` and `ARCHITECTURE.md`.
- No claim that the ported modules are original Arrowslit expression.
- Complete corresponding source for every release.

### 8. Excluded and deliberately not copied

- Keyboard shortcuts (⌃⌥ + letter) and tile shortcut labels: excluded by request.
- TelemetryDeck / usage reporting: excluded; Arrowslit stays no-telemetry.
- Notch Shell's dead `FileConverter`, `AudioOutputService`, `PerAppEQEngine` and `AudioSpectrum` code: not shipped features, not ported.
- Background goal alerts/APNs: still out of scope.
- App Store distribution, iOS/iPad, localization: out of scope for this parity effort.

---

## Testing Decisions

### What makes a good test

Tests verify behaviour at a public seam, not private methods or view internals. They should survive a refactor of the implementation. Expected values come from the Notch Shell design contract, a worked example or a fixture, not from recomputing the implementation's formula.

### Seams under test

| Seam | What it catches | What it misses |
|---|---|---|
| `LayoutEngine.layout(for:home:hovering:)` | geometry, size modes, width/thickness clamps, virtual notch, alert ears, elongated width | actual pixel rendering, Glass blur |
| `PresentationResolver.resolve(_:)` | hidden/idle/compact/expanded/alert/drop priority, sports priority | animation timing |
| `NotchAppearance.clamped()` | invalid persisted values, migration | UI affordance |
| `SettingsStore` | defaults, migration, reset, per-feature toggles | visual layout |
| `CallMonitor` with injected providers | call detection, debounce, grace, mute eligibility, hang-up fallback | real app-specific Accessibility behaviour |
| `DownloadProgressMonitor` with injected folder/progress | 1-second delay, rate/ETA, cancel, finished alert | browser-specific `Progress` publishing |
| `AgentRequest` / `AgentBridge` with injected peer validator | framing, auth, timeout, decision mapping, install/uninstall JSON | real assistant versions |
| `MediaAppFilter` / `NowPlayingService` | filtering, source switching, linger, scrolling title | media bridge quirks |
| `ClipboardHistory` / `NotesStore` / `TodoStore` | search, pins, persistence, rich-text round-trip, to-do ordering | AppKit text editing |
| `Updater` | manifest signature, size cap, checksum, version/bundle check, rollback | GitHub outage behaviour |
| Accessibility tree | every Settings switch has a name; root action exists; identifiers present | VoiceOver pronunciation quality |
| Snapshot harness | 1:1 shape, colours, typography and layout at fixed states | live Glass/backdrop, real multi-display |

### Test strategy

1. **TDD per ticket.** One failing behavioural test, one minimal implementation, then refactor under `code-review`.
2. **Unit tests** for all pure Core modules and stores.
3. **Snapshot tests** for the notch at fixed states and sizes; compare against Notch Shell reference PNGs with a small tolerance. Glass is reviewed manually because `NSVisualEffectView` is environment-dependent.
4. **Accessibility tests** that walk the Settings AX tree and assert every switch/button has a non-empty title and every parity-critical control has an identifier.
5. **Manual matrix** for system integrations: FaceTime/Zoom/Meet/Teams/Webex, Safari/Chrome downloads, five coding assistants, built-in + external displays, TCC/Keychain upgrade, Reduce Motion, VoiceOver.
6. **Performance gates:** idle CPU near zero when hidden; no polling when nothing is visible; no layout work on every mouse move far from the notch; memory stable over a 24-hour run.

### Prior art

- Arrowslit already tests pure rules (`CoreTests`, `FoundationTests`, `SportsTests`) with Swift Testing.
- Notch Shell has 20 test files covering layout, presentation, Glass/Downloads/Agents, media filtering, pins, updates and scrolling titles; use them as behavioural fixtures, not as a substitute for Arrowslit's own seams.

---

## Out of Scope

- Keyboard shortcuts and tile shortcut labels.
- Telemetry or usage reporting.
- Notch Shell's unwired file converter, audio output selection, per-app EQ and audio spectrum.
- APNs/background goal alerts.
- App Store distribution and notarization beyond the existing Developer ID/self-signed path.
- Localization.
- A plugin/widget API.
- Redesigning Sports beyond fitting it into the new shell.
- Removing Arrowslit's headphone alert unless the user explicitly asks for strict 1.4.2 parity.

## Further Notes

- The local `~/code/arrowslit` checkout is **Arrowslit**, a 1.4.0 fork. All parity work uses upstream `10a1dfa` (1.4.2).
- Notch Shell was run from the release DMG at `/tmp/dl142-app`; the Homebrew install on this Mac is 1.4.1.
- The Settings screenshots in `Docs/Images/` are reference material, not shipped assets.
- The plan follows the Matt Pocock workflow: spec → tickets with blocking edges → TDD per ticket → code review → integration QA. The proposed ticket breakdown is in `Docs/Notch Shell-Parity-Tickets.md`.
- Rough critical path: policy/baseline → harness → shape/motion → presentation/alerts → display/window → Home/launcher → Settings → calls/agents → QA. Signed updates can run in parallel after the policy decision.
- The estimate is intentionally not a promise: the security review for agent approvals and the multi-display QA are the two largest schedule risks.
