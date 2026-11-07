# Arrowslit — User Guide

Arrowslit turns the MacBook notch into a quiet control surface: media, timers, calendar, agent spend and approvals, clipboard, files, system stats and more. This guide covers everyday use. For screenshots and release notes, see the [README](../README.md).

## Requirements

- macOS 14 (Sonoma) or later, on Apple silicon or Intel.
- Works with or without a physical notch, and on external displays: Arrowslit draws a virtual notch at the top centre.

## Install and first launch

**Homebrew 7 (recommended):**

```bash
brew trust j4yop/tap && brew install --cask j4yop/tap/arrowslit
```

**DMG:** download the latest release from [Releases](https://github.com/j4yop/arrowslit/releases/latest), open the disk image, and drag **Arrowslit** to **Applications**.

The build is signed but not notarized, so macOS blocks the first launch. Open **Applications**, double-click **Arrowslit**, click **Done** on the warning, then go to **System Settings › Privacy & Security › Open Anyway**. If that button is missing:

```bash
xattr -dr com.apple.quarantine /Applications/Arrowslit.app
```

Arrowslit has no Dock icon. It lives in the menu bar as the slit glyph. At rest the notch stays out of sight until something is live; hover the top centre or click the menu-bar icon to open it.

## Open, close, and get around

| Action | How |
| :--- | :--- |
| Open the notch | Hover the top centre (default), click the notch, or menu-bar icon → **Open Arrowslit** |
| Close it | Move the pointer away, click outside, or press **Escape** |
| Settings | Menu-bar icon → **Settings…**, or **⌘,** |
| Switch tool | Launcher grid (top right), the top shortcut strip, or a **⌃⌥** shortcut |
| Page the launcher | Scroll or swipe vertically over the grid; use the dots on the right |

Default behaviour is hover-to-open. If you prefer click, change **Settings › General › Open notch with**. **Collapse when the pointer leaves** is on by default.

## Home

Home shows up to three live sections side by side:

- **Media** while something is playing: artwork, track, lyrics (if enabled), scrubber, and playback controls. Click the card or its expand arrow for the full Now Playing page.
- **Calendar**: your next event; click the header to open the full Calendar.
- **Timer** quick starts: **5m**, **10m**, **15m**, and **Focus** (your configured focus length). A started timer collapses the notch and keeps counting beside the camera; open Timer (`⌃⌥R`) to pause, resume, or cancel.
- **Shortcuts**, when enabled, can take the third slot (**Settings › Home › Shortcuts**).

## Every tool

Keys are **Control-Option** plus the letter and can be disabled in **Settings › General**. A dot on a launcher tile means that feature is live.

| Tool | Key | What it does |
| :--- | :--- | :--- |
| **Now Playing** | `⌃⌥M` | Full player: artwork, lyrics, scrubbable timeline, previous/pause/next |
| **Timer** | `⌃⌥R` | Sliding minute ruler, Pomodoro focus/break, Pause/Resume and Cancel |
| **Stopwatch** | `⌃⌥S` | Tenths of a second, Pause/Resume, Reset |
| **Calendar** | `⌃⌥A` | Month grid and day agenda; a five-minute heads-up with **Join** for Meet, Zoom, Teams and Webex |
| **Sports** | `⌃⌥F` | Followed teams and pinned matches, live scores and goal alerts |
| **Reminders** | `⌃⌥O` | Today's Apple Reminders; completed items optional |
| **AI Agents** | `⌃⌥G` | Live token spend and usage for Claude Code, Codex, OpenCode and Copilot, plus agent approvals |
| **Clipboard** | `⌃⌥B` | In-memory clip history, 20 clips by default; pinned clips persist |
| **Files** | `⌃⌥L` | Drop files from Finder on the notch; keep them on the Tray shelf or send them by AirDrop |
| **Scratchpad** | `⌃⌥N` | A local note that saves as you type |
| **Camera Mirror** | `⌃⌥W` | Camera preview for a quick check; the sensor turns off when the panel closes |
| **Keep Awake** | `⌃⌥Z` | Prevents system sleep; display and disk sleep stay configurable |
| **Stats** | `⌃⌥P` | Memory, CPU, disk and network; sensors sample only while the panel is visible |
| **Downloads** | — | Browser downloads with progress, **Stop** and **Show in Finder**. Off by default; enable in **Settings › Home › Downloads** |

## The launcher

Click the grid icon at the top right. The launcher holds thirteen tools in five columns and two rows per page: scroll or swipe to page, or click a page dot. The AI Agents page is always present, even when its live strip is off.

**Hold any tile** to edit the three shortcuts that sit beside Home, then click tiles to add or remove them; the keys under the tiles are the global shortcuts. For the same list of features, use **Settings › Home**.

## Live activities

While the notch is closed, the strip beside the camera keeps the most useful thing in view: a call, a running timer, the stopwatch, a working agent, the next meeting, a followed match, now playing, a download, or a battery/charging notice. Alerts slide out briefly; timers and other ongoing work return to the strip afterwards.

Choose what is allowed in **Settings › Activities** (calls, agents, media apps, sports, lyrics) and **Settings › Notch** (live feedback, live activities, and the feature switches).

## Settings

| Tab | What lives there |
| :--- | :--- |
| **General** | Open at login, menu-bar icon, Settings on launch, display choice, **Show when idle**, open with click/hover and hover delay, collapse on leave, liquid animations, haptics, keyboard shortcuts, timer defaults |
| **Appearance** | Standard or Elongated Home, Black or Glass theme, glass tint, pitch black, outline, size (Small/Medium/Large), width and thickness, **Restore Defaults** |
| **Activities** | Calls and microphone, call strip, Coding Assistants (approval hooks), AI Agents usage, Now Playing apps, paused-media duration, sports, timed lyrics |
| **Notch** | HUD duration, battery thresholds, live feedback events, live activity strips, feature switches |
| **Home** | Which features appear in the launcher, launcher shortcuts, downloads and watched folder, clipboard, camera, stats, Keep Awake, Reminders, Calendar, Shortcuts |
| **About** | Version, **Check for Updates**, links and licence |

## Agent approvals

Open **Settings › Activities › Coding Assistants** and switch on an assistant to add Arrowslit's hook: Claude Code, Codex, Copilot CLI, Antigravity, Cursor, or OpenCode. New sessions pick it up.

When an agent wants to run a command or change a file, the request appears in the notch with **Allow**, **Deny**, and **Ask in CLI**. Closing the alert or waiting about two minutes returns the question to the assistant — nothing is auto-allowed. The trust model and failure behaviour are documented in [Agent-Approval-Security.md](Agent-Approval-Security.md).

## Privacy and permissions

- No account, no sign-in, no analytics or telemetry. Update checks query GitHub anonymously.
- **Clipboard:** history stays in RAM up to the length you choose (20 by default); only clips you pin are written to disk. Password-manager and private items are skipped by default. You can clear the history or change the capacity in Settings.
- **Calendar, Reminders, Camera:** macOS asks only when you open or connect that tool. Declining disables that panel only.
- **Lyrics:** off by default. When on, only title, artist, album and track length are sent to lrclib.net.
- **Sports:** preview matches are generated locally; live scores use your own BigBallsData key.
- **Agent usage:** read from the assistants' local data on your Mac.

## Update and uninstall

- **In-app:** **Settings › About › Check for Updates**. Arrowslit also checks at launch and once a day; an update is verified (Ed25519 manifest, size, SHA-256) before **Install and Relaunch**.
- **Homebrew:** `brew upgrade --cask arrowslit`
- **Uninstall:** menu-bar icon → **Quit Arrowslit**, then drag **Arrowslit** from Applications to the Trash. To remove local settings and notes as well, delete `~/Library/Preferences/com.j4yop.arrowslit.plist` and `~/Library/Application Support/Arrowslit`.

## Troubleshooting

| Problem | Fix |
| :--- | :--- |
| Nothing is on screen | Intentional at rest. Hover the top centre, use the menu-bar icon, or turn on **Show when idle** |
| No physical notch | A virtual notch appears at the top centre and behaves the same |
| Music is missing | Start playback and give media a second; check **Settings › Activities › Now Playing Apps** and the paused-media duration |
| Calendar or Reminders is empty | Grant access when prompted; check the Calendar/Reminders sections in **Settings › Home** |
| A shortcut does nothing | Enable **Settings › General › Keyboard shortcuts**; another app may already own the combination |
| Notch is on the wrong screen | **Settings › General › Display**: Built-in, Main, Follow the pointer, All displays, or a named screen |
| The timer strip is gone | Check **Settings › Notch › Live activities** and the Timer feature switch |
| The notch looks off | **Settings › Appearance › Restore Defaults** |

## More

- [Source](https://github.com/j4yop/arrowslit) · [Releases](https://github.com/j4yop/arrowslit/releases/latest) · [Issues](https://github.com/j4yop/arrowslit/issues)
- [Agent approval security](Agent-Approval-Security.md) · [Architecture](../ARCHITECTURE.md)
- Arrowslit is free software under GPL-3.0.
