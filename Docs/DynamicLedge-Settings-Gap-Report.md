# DynamicLedge 1.4.2 Settings vs Arrowslit 0.9.2 — gap report

**Date:** 2 November 2026  
**DynamicLedge:** 1.4.2 build 78, run from the official release DMG (the Homebrew install on this Mac is 1.4.1)  
**Arrowslit:** 0.9.2 build 34 (`6887c9a`)  
**Method:** launched both apps, opened Settings, captured every DynamicLedge tab and the Arrowslit page, then cross-checked every control against the 1.4.2 source and Arrowslit's `SettingsView`.

**Screenshots captured for this report:**

| Window | Image |
|---|---|
| DynamicLedge 1.4.2 — General | `Docs/Images/dl-142-general.png` |
| DynamicLedge 1.4.2 — Appearance | `Docs/Images/dl-142-appearance.png` |
| DynamicLedge 1.4.2 — Activities (top) | `Docs/Images/dl-142-activities-top.png` |
| DynamicLedge 1.4.2 — Activities (lower) | `Docs/Images/dl-142-activities-lower.png` |
| DynamicLedge 1.4.2 — Home (top) | `Docs/Images/dl-142-home-top.png` |
| DynamicLedge 1.4.2 — Home (lower) | `Docs/Images/dl-142-home-lower.png` |
| DynamicLedge 1.4.2 — About | `Docs/Images/dl-142-about.png` |

Arrowslit's own settings window is not included as an image because the captured pane showed a partial API-key hint; the report describes it from the live window and source instead.

---

## 1. Executive summary

DynamicLedge's Settings is a **five-tab system-style window**:

| Tab | Purpose |
|---|---|
| General | Login, menu bar, display, lock screen, behaviour, timer lengths |
| Appearance | Layout, theme, glass, size, width, thickness |
| Activities | Live activities, media apps, coding assistants, alerts, linger |
| Home | Feature toggles, calendar access, Shortcuts |
| About | Version, updates, source/licence |

Arrowslit's Settings is a **single 540×652 scrolling page** of custom black cards.

Counting distinct controls (not section headers or footers), DynamicLedge has **56**; Arrowslit has equivalents for **25**, partial equivalents for **3**, is missing **27**, and **1** is excluded by request (keyboard shortcuts).

The biggest gaps are not small controls:

1. **Display picker** — built-in, main, named display, follow pointer or all displays.
2. **Appearance engine** — Standard/Elongated, Black/Glass, glass tint, pitch black, Small/Medium/Large, width, thickness, restore defaults.
3. **Calls & Microphone** — the largest missing live activity.
4. **Coding-assistant approvals** — five assistants, each with a setting.
5. **Download progress** — finished downloads and live progress.
6. **Media app filtering** and paused-media linger.
7. **Shortcuts runner** on Home.
8. **In-place updates** with signature verification.
9. **Accessibility labels** — every Arrowslit switch is currently unlabelled to VoiceOver.

Arrowslit still has settings DynamicLedge does not: the whole **Sports** section (key, competitions, preview, live score, goal alerts, refresh, quota), plus Stopwatch/Keep Awake toggles, the headphone alert, Open Settings on launch, and Reminders/Camera access rows.

---

## 2. Visual comparison

| | DynamicLedge 1.4.2 | Arrowslit 0.9.2 |
|---|---|---|
| Window | 520 pt wide; height changes by tab (468–688) | 540×652 fixed |
| Navigation | 5 toolbar tabs with icons and labels | one scrolling page |
| Form style | native `Form(.grouped)`, inset rounded sections | custom black cards with hairline borders |
| Accent | system blue switches and segmented controls | amber switches and checkmarks |
| Toggles | `Toggle` owns the row label | separate `Text` + unlabelled `Toggle("")` |
| Section help | footers under groups | notes above groups |
| About | icon, version, update control, source/licence links | name, version, privacy note, GPL line |

The visual difference matters for parity: even if every feature were added, Arrowslit would still not look like DynamicLedge because the settings surface is a different design language.

---

## 3. General tab

| # | DynamicLedge control | Behaviour / default | Arrowslit 0.9.2 | Status | Gap and action |
|---|---|---|---|---|---|
| G1 | Open at login | Registers the app as a login item | Interface › Open at login | ✅ Equivalent | Keep; move to General. |
| G2 | Show in menu bar | Shows the status item | Interface › Show menu bar icon | ✅ Equivalent | Keep; move to General. |
| G3 | Display | Built-in, Main, named display, Follow pointer, All displays | Built-in only | ❌ Missing | Add display choice, UUID persistence and mirror windows. Ticket 05. |
| G4 | Show on Lock Screen | Timer/music/charging on the lock screen | Standalone Lock Screen section | ✅ Equivalent | Keep; move under General. |
| G5 | Show when idle | Keeps an empty pill visible | Always shows the clock strip | ❌ Missing | Add hidden-at-rest + Show when idle. Ticket 04. |
| G6 | Open notch with | Click or Hover, segmented | "Open notch on hover" checkbox | 🟡 Partial | Replace checkbox with Click/Hover picker. Ticket 03/05. |
| G7 | Hover delay | 0.1–0.5 s, default 0.4 | Fixed ~0.4 s | ❌ Missing | Add delay picker. Ticket 05. |
| G8 | Collapse when pointer leaves | On | Same | ✅ Equivalent | Keep. |
| G9 | Liquid animations | On | Same | ✅ Equivalent | Keep; wire to the new shape/pulse. |
| G10 | Haptic feedback | On | Same | ✅ Equivalent | Keep. |
| G11 | Keyboard shortcuts (⌃⌥ + letter) | On | None | ⛔ Excluded | Do not add; user explicitly declined. |
| G12 | Play a sound when a timer ends | On | Same | ✅ Equivalent | Keep. |
| G13 | Focus session | 15/25/45/50/60 min | Fixed 25 min | ❌ Missing | Add focus length picker. Ticket 09/14. |
| G14 | Break | 5/10/15 min | Fixed 5 min | ❌ Missing | Add break length picker. Ticket 09/14. |

---

## 4. Appearance tab

| # | DynamicLedge control | Behaviour / default | Arrowslit 0.9.2 | Status | Gap and action |
|---|---|---|---|---|---|
| A1 | Home layout | Standard or Elongated | Fixed standard | ❌ Missing | Add elongated Home/Tray/Clipboard. Ticket 08. |
| A2 | Theme | Black or Glass | Always black | ❌ Missing | Port GlassSurface and theme motion. Tickets 02–03. |
| A3 | Glass tint | Clear → tinted slider | None | ❌ Missing | Add tint slider, persist and clamp. Ticket 03. |
| A4 | Pitch black | Removes shadow/outline | Always flat black with hairline | ❌ Missing | Add pitch-black toggle and surface variants. Ticket 03. |
| A5 | Size | Small 0.8, Medium 0.9, Large 1.0 | Fixed scale | ❌ Missing | Add size modes and content scale. Ticket 02. |
| A6 | Width | 120–420 pt | Fixed 320–420 compact | ❌ Missing | Add width slider and ear calculation. Ticket 02. |
| A7 | Thickness | 24–52 pt | Fixed 32 | ❌ Missing | Add thickness slider and notch-height clamp. Ticket 02. |
| A8 | Restore Defaults | Resets appearance | None | ❌ Missing | Add reset and disabled state. Ticket 03. |

**Note:** DynamicLedge shows the shape live while Appearance is open. Arrowslit's settings window currently collapses the notch and does not preview changes; parity needs the live preview.

---

## 5. Activities tab

| # | DynamicLedge control | Behaviour / default | Arrowslit 0.9.2 | Status | Gap and action |
|---|---|---|---|---|---|
| C1 | Now Playing | On | Features › Now Playing | ✅ Equivalent | Keep. |
| C2 | Lyrics | On by default | Music › Show timed lyrics, off by default | ✅ Equivalent | Keep Arrowslit's privacy default; note the default differs. |
| C3 | Timer | On | Features › Timer | ✅ Equivalent | Keep. |
| C4 | Calls & Microphone | On | None | ❌ Missing | Port CallMonitor, mute and hang-up. Ticket 10. |
| C5 | AirDrop | On | AirDrop drop zone always available; no setting | 🟡 Partial | Add a real toggle and hide the AirDrop zone when off. Ticket 15. |
| C6 | Show music from | All apps / Only these apps | Always all apps | ❌ Missing | Add MediaAppFilter settings. Ticket 12. |
| C7 | Per-app media list + Add App | Icons, checkboxes, remove | None | ❌ Missing | Add app picker and recent-app suggestions. Ticket 12. |
| C8 | Claude Code | Off; installs hook | None | ❌ Missing | Add approval hook + security review. Ticket 16. |
| C9 | Codex | Off; installs hook | None | ❌ Missing | Same. Ticket 16. |
| C10 | Copilot CLI | Off; installs hook | None | ❌ Missing | Same. Ticket 16. |
| C11 | Antigravity | Off; installs hook | None | ❌ Missing | Same. Ticket 16. |
| C12 | Cursor | Off; installs hook | None | ❌ Missing | Same. Ticket 16. |
| C13 | Charging | On | Alerts › Charging | ✅ Equivalent | Keep. |
| C14 | Low Battery | On, 20%/10% | Same | ✅ Equivalent | Keep. |
| C15 | Volume & Brightness | On | Same | ✅ Equivalent | Keep. |
| C16 | Keep paused media for | 10/30/60/300 s, default 30 | Drops paused media immediately | ❌ Missing | Add linger setting and timing. Ticket 12. |

**Important:** the coding-assistant toggles are not simple preferences. Turning one on writes a hook into that assistant's settings file; turning it off removes it. The report's feature audit covers the security model in detail.

---

## 6. Home tab

| # | DynamicLedge control | Behaviour / default | Arrowslit 0.9.2 | Status | Gap and action |
|---|---|---|---|---|---|
| H1 | File Tray | On; up to 30, pinned survive quit | Features › File Tray | ✅ Equivalent | Keep. |
| H2 | Allow document window dragging | Accessibility prompt | Same button in File Tray row | ✅ Equivalent | Keep. |
| H3 | Clipboard | On; password markers skipped; pins saved | Features › Clipboard | ✅ Equivalent | Feature depth (search/pins) missing, but the toggle exists. Ticket 13. |
| H4 | Notes | On; rich text | Features › Scratchpad; plain text | ✅ Equivalent | Toggle exists; rich text missing. Ticket 14. |
| H5 | Reminders | On; today's to-dos | Features › Reminders | ✅ Equivalent | Keep. |
| H6 | Finished downloads | Off; Downloads access | None | ❌ Missing | Add toggle, watcher and alert. Ticket 11. |
| H7 | Mirror | On; camera preview | Features › Mirror | ✅ Equivalent | Keep. |
| H8 | Stats | Off; compact CPU/memory | Features › Stats, on by default | ✅ Equivalent | Keep; align default or document the difference. |
| H9 | Calendar | On; next event + 5-min heads-up | Features › Calendar | ✅ Equivalent | Keep. |
| H10 | Access | Allowed / Connect / Open Privacy Settings | Access › Calendar | ✅ Equivalent | Keep; move under Calendar for parity. |
| H11 | Shortcuts | On; run favourite Shortcuts | None | ❌ Missing | Add ShortcutsService and Home section. Ticket 14. |
| H12 | Favourite Shortcuts | Pick up to 4 | None | ❌ Missing | Add picker and running state. Ticket 14. |

---

## 7. About tab

| # | DynamicLedge control | Behaviour / default | Arrowslit 0.9.2 | Status | Gap and action |
|---|---|---|---|---|---|
| B1 | Check for updates automatically | On | Updates › Check automatically | ✅ Equivalent | Keep. |
| B2 | Check / Install and Relaunch | Verifies, installs, relaunches | Download & Open DMG | 🟡 Partial | Port signed in-place update. Ticket 17. |
| B3 | Source Code link | GitHub repository | None | ❌ Missing | Add link. Ticket 09. |
| B4 | License link | GPL-3.0 | GPL line only, no link | ❌ Missing | Add link. Ticket 09. |
| B5 | Version and build | e.g. 1.4.2 (78) | Version only | ✅ Equivalent | Add build number for parity. Ticket 09. |
| B6 | Copyright | Upstream copyright | Arrowslit copyright | ✅ Equivalent | Keep Arrowslit's, plus upstream attribution if Path A. |

---

## 8. Settings that exist only in Arrowslit

These are not gaps; they are intentional extensions that must survive the parity port.

| Arrowslit setting | Where | Why keep |
|---|---|---|
| Sports in launcher | Sports | Turns the football feature on/off. |
| BigBallsData key | Sports | Keychain-backed live data. |
| Preview with sample matches | Sports | Works without a key. |
| Show live score in notch | Sports | The compact score. |
| Goal notifications | Sports | Popup + haptic. |
| Refresh while Sports is open | Sports | 30/60/120 s, quota-aware. |
| Competitions | Sports | Six football leagues. |
| Quota / Data by BigBallsData | Sports | Free-tier transparency. |
| Stopwatch | Features | DynamicLedge has a stopwatch tile but no settings toggle. |
| Keep Awake | Features | DynamicLedge has it in the launcher but no settings toggle. |
| Headphones alert | Alerts | DynamicLedge removed it in 1.4.2 because macOS already shows it; Arrowslit keeps it. |
| Open Settings on launch | Interface | DynamicLedge opens Settings only on reopen; Arrowslit's explicit option is useful. |
| Reminders access | Access | Arrowslit exposes a separate permission row. |
| Camera access | Access | Arrowslit exposes a separate permission row. |

**Decision:** strict 1:1 would remove the headphone alert and the Stopwatch/Keep Awake toggles. The recommended path is to keep them as visible Arrowslit extensions, clearly separated from parity settings, unless the user wants literal 1.4.2 parity.

---

## 9. Accessibility gaps in Settings

These are concrete defects, not just parity differences.

### 9.1 Every Arrowslit switch is unlabelled to VoiceOver

`SettingsToggle` and `AlertToggleRow` render:

```swift
Text(title)
Toggle("", isOn: $isOn)
    .labelsHidden()
```

The switch has no accessible name. VoiceOver announces an unlabelled switch, so a blind user cannot tell whether they are changing Charging, Low Battery, Haptics or Open at login.

DynamicLedge's `IconToggle` uses `Toggle(isOn:) { ... }`, so the row content is the switch's label. The parity port must adopt that pattern for **every** toggle, including the Sports competition buttons, File Tray row and Lock Screen row.

### 9.2 Other gaps

| Gap | Arrowslit | DynamicLedge | Action |
|---|---|---|---|
| Root "Open Home" action | None | `accessibilityAction(named: "Open Home")` | Add to the compact/hidden root. |
| Spoken time | `ClockFormat.clock` only | `TimeFormatting.spoken` | Add "4 minutes, 59 seconds". |
| Accessibility identifiers | 0 | 2 | Add for tabs, grid, shortcut editor, parity controls. |
| Icon-only labels | Sports follow/pin use `.help` only | App icons labelled | Add `.accessibilityLabel`. |
| Menu-bar icon description | Custom image, no description | System symbol with description | Add `accessibilityDescription`. |
| Hit slop | None | 4 pt | Add around compact shapes and small buttons. |
| Dynamic Type | Not handled | Not handled | Shared gap; out of parity scope but note it. |
| Increase Contrast | Not handled | Not handled | Shared gap. |
| Differentiate Without Colour | Not handled | Not handled | Shared gap. |

### 9.3 Settings tab semantics

DynamicLedge's tab toolbar exposes five buttons with names; Arrowslit has no tabs. When the shell is replaced, each tab must be an accessible button with a selected trait, and the window title must follow the selected tab.

---

## 10. Recommended order

### P0 — parity shell and safety

1. Five-tab Settings shell with native `Form(.grouped)` and labelled toggles (ticket 09).
2. Display picker, Show when idle, click/hover + delay (tickets 03–05).
3. Appearance engine: layout, theme, glass, size, width, thickness, reset (tickets 02–03).
4. Calls & Microphone (ticket 10).
5. Signed in-place updates (ticket 17).

### P1 — daily depth

6. Downloads (ticket 11).
7. Media filter, switcher, scrolling title, linger (ticket 12).
8. Clipboard search/pins (ticket 13).
9. Rich Notes, Shortcuts runner, to-dos (ticket 14).
10. Agent approvals, after security review (ticket 16).

### P2 — completeness

11. Elongated layout (ticket 08).
12. Launcher pages and hold-to-edit (ticket 07).
13. Tray links, drop preview, compact Stats, second bubble (ticket 15).
14. About links and build number (ticket 09).
15. Full accessibility audit and release QA (ticket 18).

---

## 11. Exact DynamicLedge 1.4.2 settings inventory

For traceability, this is the full control list observed in the running 1.4.2 app and confirmed in `Sources/NotchKit/Settings/SettingsViews.swift`:

**General:** Open at login · Show in menu bar · Display · Show on Lock Screen · Show when idle · Open notch with · Hover delay · Collapse when pointer leaves · Liquid animations · Haptic feedback · Keyboard shortcuts · Play a sound when timer ends · Focus session · Break.

**Appearance:** Home layout · Theme · Glass tint / Pitch black · Size · Width · Thickness · Restore Defaults.

**Activities:** Now Playing · Lyrics · Timer · Calls & Microphone · AirDrop · Show music from · per-app media list · Add App · Claude Code · Codex · Copilot CLI · Antigravity · Cursor · Charging · Low Battery · Volume & Brightness · Keep paused media for.

**Home:** File Tray · Allow document window dragging · Clipboard · Notes · Reminders · Finished downloads · Mirror · Stats · Calendar · Access · Shortcuts · favourite Shortcuts.

**About:** Check for updates automatically · Check for Updates / Install and Relaunch · Source Code · License · version/build · copyright.

---

## 12. Bottom line

Arrowslit's Settings is not a smaller version of DynamicLedge's; it is a different design with a different information architecture. Adding the missing rows to the current page would produce a long, inconsistent list and would still miss the display/appearance shell that most of those rows control.

The parity work should therefore replace the Settings shell at the same time as the notch shell, then add feature sections in the order above. The accessibility fix for toggle labels should ship with the first Settings ticket, not at the end.
