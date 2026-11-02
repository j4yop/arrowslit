# Vorssaint Notch Port

**Branch:** `feat/vorssaint-notch`
**Source:** Vorssaint v3.4.3, commit `a5da763` (GPL-3.0-or-later)
**Target:** Arrowslit's notch / Dynamic Island surface

This branch replaces the old 560×178 tabbed nook with a 596×256 Vorssaint-style
Explore surface. It keeps Arrowslit's existing services and tab model underneath,
so the port does not create a second app or a second set of stores.

## What is exact

- **Panel footprint:** 596 × 256 pt, 5 columns × 2 rows, three pages, 3 page dots.
- **Explore order:** Controls, Volume mixer, Now Playing, Clipboard, Recent captures,
  Files, System, Tools, Calendar, Notifications, Timer, Camera mirror, Downloads,
  Scratchpad, AI Agents, Watch. Arrowslit's own sports, reminders, stopwatch,
  keep-awake, call and home pages live on the third page.
- **Tile language:** black rounded tiles, 20-pt icon, 11.5-pt title, ⌥⌘ shortcut,
  hover wash, press spring, live/check marks.
- **Header:** back to Explore, house to Home, settings gear, page dots.
- **Shortcuts:** each page has its Vorssaint ⌥⌘ letter; global hotkeys are registered
  alongside Arrowslit's existing ⌃⌥ shortcuts.
- **AI reader:** the Vorssaint AgentUsage service and its Claude/Codex/OpenCode/Copilot
  readers, pricing, archive, limits and Codex reset flow are copied under
  `Sources/ArrowslitKit/Services/AgentUsage/` with GPL attribution in `NOTICE`.
- **AI page:** Limits, Spending, Now, Trend, Models, Projects, Activity and Resets cards.
- **Timer:** native minute ruler with drag, scroll, arrow keys, Home/End, VoiceOver
  adjustment and a haptic on each changed minute.
- **Settings:** new AI Agents tab with provider switches and a Companion switch.
- **Mixer:** system output volume, output-device picker and microphone mute.
- **Captures:** area/screen capture into `~/Pictures/Arrowslit Captures`, with a
  recent-capture strip and Finder handoff.
- **Notifications:** a recent-alert inbox fed by the notch's own alert history.
- **Watch:** local full-display OCR with changes / settles / contains conditions.
- **Companion:** a lightweight SwiftUI character with blinking, moods, petting
  and trackpad haptics in the Controls page.
- **Optionality:** the island remains optional; the page grid is reachable only when
  the island is opened, and the existing feature switches still stop their services.

## What is not yet a literal 1:1 copy

These Vorssaint subsystems are larger than a UI port and are intentionally not
claimed as finished here:

1. **Per-app audio mixer.** Arrowslit now has system output, device routing and mic
   mute. Vorssaint's `AppVolumeMixer` (3,843 lines of Core Audio process taps,
   aggregate devices, per-app gain and AirPlay routing) is not ported yet.
2. **System notification mirroring.** The Notifications page is a local alert inbox,
   not Vorssaint's Accessibility-based Notification Center banner reader. It does
   not read or hide other apps' banners.
3. **Audio-reactive equalizer.** Arrowslit still uses its synthetic `MusicBars`.
   Vorssaint's 7-band Core Audio process tap is not ported.
4. **Full companion rig.** The companion is a small SwiftUI character, not the
   〜1,300-line Core Animation rig with visits, 14 reactions, stage preview and
   drag-following.
5. **Capture editor/recorder.** Screenshot area/screen capture exists; Vorssaint's
   annotation editor, scrolling capture, screen recorder, GIF/video export and
   temporary links are not ported.
6. **Watch region selection.** Watch reads the main display; Vorssaint lets you
   choose an arbitrary window region.
7. **Silhouette morph.** The panel size animates with Arrowslit's existing spring;
   Vorssaint's per-frame `CAKeyframeAnimation(path)` morph is not copied.
8. **AI account UI.** The reader and all eight cards are present; Vorssaint's
   account pickers, card-order editor and per-card visibility editor are not.

## Validation

- `swift build --build-system native` passes.
- `swift test --build-system native` passes: 168 tests in 49 suites.
- A dev bundle was built at `/tmp/ArrowslitVorssaint.app` (bundle id
  `com.j4yop.arrowslit.dev`) and the Explore grid, page 2, AI page, Timer ruler,
  Controls, Mixer, Captures and Notifications were checked on screen.
- Existing Arrowslit behavior is unchanged outside the launcher surface; the old
  `LauncherPane` remains in the tree for reference but is no longer used by
  `NookView`.
