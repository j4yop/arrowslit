# Inspiration and differentiation

Arrowslit is built from scratch. We studied the public feature sets of free and open-source
notch projects to understand what people expect, then made different choices about the interface,
scope and privacy. No source, assets or UI text were copied.

## Free / open-source projects studied

| Project | Strong ideas | What Arrowslit does differently |
|---|---|---|
| **Boring Notch** | Music + visualizer, calendar, file shelf, AirDrop, mirror, HUD, battery | A vertical "aperture" rail instead of a horizontal widget strip; local-only core; no visualizer by default |
| **Atoll** | Media, Focus, screen recording, stats, clipboard, timers, lock screen, heavy customization | Fewer modules, deeper keyboard flow; stats and clipboard foregrounded; no telemetry or account |
| **NotchNest** | Clipboard search and pinning, quick notes, Pomodoro | Clipboard + scratchpad share one rail; add search/pin next; timer stays one tap away |
| **Itchy** | Twelve modules, notes, clipboard, Pomodoro, mail | Deliberately small: timer, calendar, clipboard, notes, stats first; no module sprawl |
| **NotchBox** | Clipboard, Pomodoro, notes, bookmarks | Privacy-first clipboard and a single scratchpad instead of many niche tools |
| **NotchDodo** | Clipboard that skips passwords, focus sounds | Same privacy rule; no sounds by default; focus timer is native and quiet |
| **ComfyNotch** | Widgets, music, brightness/volume | A single workbench with a rail; appearance is restrained rather than widget-heavy |
| **QuakeNotch** | Terminal from the notch | Not a terminal; a productivity surface, not a developer toy |
| **DropNotch** | AirDrop / Mail / Messages drop zone | Tray + AirDrop planned; no messaging integrations |
| **Notchly / Notchlight / Notchbird / notchman** | Current generation of notch apps | Different name, warm/architectural identity, local-only promise, open-source core |

## What we deliberately avoid

- Copying another app's layout, dimensions, colours, copy or animation curves.
- Network accounts, analytics, ads, subscriptions or telemetry.
- Private APIs at launch (except an optional media helper later).
- A giant grid of every possible widget. The rail stays small and legible.
- Marketing that claims "Dynamic Island" ownership; the notch is the surface, not the brand.

## Our point of view

The notch is the smallest useful screen on the Mac. Arrowslit treats it like an aperture: a
narrow opening that gives you a full view of the few things you need right now — time, the next
event, what you copied, a thought, the machine's pulse — without opening a full app.
