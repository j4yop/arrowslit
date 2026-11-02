# Vorssaint Notch Port

**Branch:** `feat/vorssaint-notch`
**Source:** Vorssaint v3.4.3, commit `a5da763` (GPL-3.0-or-later)
**Target:** Arrowslit's notch / Dynamic Island surface

This branch replaces the old 560×178 tabbed nook with Vorssaint's floating
expanded island. It keeps Arrowslit's existing services and tab model underneath,
so the port does not create a second app or a second set of stores.

## What is exact

- **Floating layer:** a 560-pt panel inside a 704-pt window with 72-pt gutters,
  44-pt quick-access circles, 54-pt row spacing and a player circle hanging below.
  The panel is 244 pt on compact pages and 328 pt on the AI page; the window grows
  from 316 to 400 pt with the same spring.
- **Quick access:** Explore/back and Timer on the left; Settings and Volume mixer on
  the right; Now Playing below the panel. The circles spring out from behind the
  panel with the reference's scale and offset.
- **Explore:** 5 columns × 2 rows, three pages, vertical page dots, wheel paging,
  back and search in the header, and the recorded #1a1a1a tiles.
- **Page header:** one Vorssaint title row with the ellipsis menu; *Keep open*,
  *Settings…* and *Collapse* live in the reference's rounded grey menu.
- **Explore order:** Controls, Volume mixer, Now Playing, Clipboard, Recent captures,
  Files, System, Tools, Calendar, Notifications, Timer, Camera mirror, Downloads,
  Scratchpad, AI Agents, Watch. Arrowslit's own sports, reminders, stopwatch,
  keep-awake, call and home pages live on the third page.
- **Tile language:** black rounded tiles, 20-pt icon, 11.5-pt title, ⌥⌘ shortcut,
  hover wash, press spring, live/check marks.
- **Page layouts:** capsule faders and orange boost levels in the mixer; the
  3-column System grid; the circular Tools rail; the week/month Calendar with event
  dots and agenda; Timer/Pomodoro/Stopwatch tabs over the orange minute ruler; the
  large-cover player with the white timeline and Lyrics/Up next pills; the Watch
  empty state; a 2×2 capture grid; and the Downloads folder prompt.
- **Shortcuts:** each page has its Vorssaint ⌥⌘ letter; global hotkeys are registered
  alongside Arrowslit's existing ⌃⌥ shortcuts.
- **AI reader:** the Vorssaint AgentUsage service and its Claude/Codex/OpenCode/Copilot
  readers, pricing, archive, limits and Codex reset flow are copied under
  `Sources/ArrowslitKit/Services/AgentUsage/` with GPL attribution in `NOTICE`.
- **AI page:** Limits, Spending, Now, Trend, Models, Projects, Activity and Resets cards.
- **Timer:** native minute ruler with drag, scroll, arrow keys, Home/End, VoiceOver
  adjustment and a haptic on each changed minute.
- **Settings:** new AI Agents tab with provider switches and a Companion switch.
- **Per-app mixer:** the Vorssaint Core Audio process-tap mixer, with per-app gain,
  mute, output routing, system output, output-device picker and mic mute.
- **Captures:** area/screen capture into `~/Pictures/Arrowslit Captures`, with a
  recent-capture strip and Finder handoff.
- **Notifications:** an Accessibility reader for new visible Notification Center
  banners, a session inbox, open/dismiss, and optional native-banner hiding.
- **Watch:** local full-display OCR with changes / settles / contains conditions.
- **Companion:** a lightweight SwiftUI character with blinking, moods, petting
  and trackpad haptics in the Controls page.
- **Optionality:** the island remains optional; the page grid is reachable only when
  the island is opened, and the existing feature switches still stop their services.

## What is not yet a literal 1:1 copy

These Vorssaint subsystems are larger than a UI port and are intentionally not
claimed as finished here:

1. **AirPlay routing.** The per-app Core Audio mixer is ported; Vorssaint's private
   AirPlay/AVOutputContext path is stubbed, so the AirPlay sentinel is not offered.
2. **Audio-reactive equalizer.** Arrowslit still uses its synthetic `MusicBars`.
   Vorssaint's 7-band Core Audio process tap is not ported.
3. **Full companion rig.** The companion is a small SwiftUI character, not the
   〜1,300-line Core Animation rig with visits, 14 reactions, stage preview and
   drag-following.
4. **Capture editor/recorder.** Screenshot area/screen capture exists; Vorssaint's
   annotation editor, scrolling capture, screen recorder, GIF/video export and
   temporary links are not ported.
5. **Watch region selection.** Watch reads the main display; Vorssaint lets you
   choose an arbitrary window region.
6. **Silhouette morph.** The panel size animates with Arrowslit's existing spring;
   Vorssaint's per-frame `CAKeyframeAnimation(path)` morph is not copied.
7. **AI account UI.** The reader and all eight cards are present; Vorssaint's
   account pickers, card-order editor and per-card visibility editor are not.

## Validation

- `swift build --build-system native` passes.
- `swift test --build-system native` passes: 172 tests in 50 suites.
- The signed app was installed as `/Applications/Arrowslit.app`, version
  `0.11.0-vorssaint` build 212, and the 704-pt floating layer, Explore paging by
  dots and wheel, AI page height, Timer tabs and ruler, System grid, Tools rail,
  Calendar, Watch, Captures, Downloads prompt, Clipboard, Scratchpad, Controls,
  real per-app Mixer and Notifications were checked on screen.
- Notification mirroring remains **Paused** until Arrowslit is switched on in
  System Settings › Privacy & Security › Accessibility.
- Existing Arrowslit behavior is unchanged outside the launcher surface; the old
  `LauncherPane` remains in the tree for reference but is no longer used by
  `NookView`.


## Notification permission

System notification mirroring uses Accessibility to read the visible
Notification Center banner hierarchy. Until Arrowslit is switched on in
System Settings › Privacy & Security › Accessibility, the Notifications page
shows **Paused** and offers a direct button to that pane. It never reads the
notification database, message stores or history.
