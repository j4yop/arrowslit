<p align="center">
  <img src="Support/AppIcon-1024.png" width="128" alt="Arrowslit icon">
</p>

<h1 align="center">Arrowslit</h1>

<p align="center">
  A quiet control surface for your MacBook notch.<br>
  <b><a href="https://github.com/j4yop/arrowslit/releases/download/v0.1.0/Arrowslit-0.1.0.dmg">Download Arrowslit 0.1.0</a></b> (free, universal build, macOS 14+)
</p>

---

Arrowslit turns your MacBook notch into a narrow aperture. It stays out of your way until you need it, then opens into a compact, distraction-free workbench for music, timers, files, clipboard history, notes, reminders, and system stats.

Built from scratch in Swift, Arrowslit is completely local. No accounts, no analytics, no background network calls, and zero idle battery drain.

### Here is what sits beside the camera

When closed, the notch strip stays flush against the top of your screen:

* **Live clock**: Wall clock in India Standard Time or local time.
* **Running timers**: Active countdowns right next to the camera lens.
* **Now Playing**: Current track title and animated music bars when audio is playing.
* **Drop zone**: Drag files straight onto the closed notch to drop them into your tray.

### Click or hover the notch to open the workbench

A 560×178 pt surface slides down from the camera housing:

* **Home**: Media player with album art on the left, next calendar meeting, quick timer presets, and live CPU/memory stats on the right.
* **Now Playing**: Full player with artwork, track scrubber, elapsed time, and transport controls.
* **Timer & Focus**: Quick presets (5m, 10m, 25m, 50m), a dedicated 25-minute Pomodoro focus session with 5-minute break cycling, and a tenths-of-a-second stopwatch.
* **Files (Tray)**: A handy shelf for files you need for a moment. Drag files in, drag them back out, or send them over AirDrop with one click. The tray clears when you quit Arrowslit.
* **Clipboard**: The last 20 text snippets you copied. Click any snippet to copy it again. Passwords and sensitive data from password managers (1Password, concealed types) are skipped automatically. Nothing is saved to disk.
* **Scratchpad (Notes)**: A quick notepad for phone numbers, ideas, or links. Saves automatically into local storage as you type.
* **Calendar & Reminders**: Upcoming meetings with start times, plus today's tasks from Apple Reminders that you can check off directly in the notch.
* **Camera Mirror**: Check your lighting, hair, and framing before hopping on a video call. The camera shuts off completely when you leave the tab.
* **System Stats**: CPU core usage and memory pressure gauges that only sample while you look at them, keeping idle battery draw at zero.
* **Keep Awake**: Prevents your Mac from sleeping with one click, while still allowing the screen to turn off.
* **Custom Shortcuts**: Pick up to three of your favorite tools to sit right beside Home at the top left. Change them anytime by opening the launcher and clicking the pencil.

---

## Installing it

### The easy way, with [Homebrew](https://brew.sh)

```bash
brew trust j4yop/tap && brew install --cask j4yop/tap/arrowslit
```

Homebrew 7 asks you to trust a third-party tap once. The cask clears the quarantine flag automatically, so you can open Arrowslit right away.

On Homebrew versions before 7, run:

```bash
brew install --cask j4yop/tap/arrowslit
```

### Direct download

1. Download **[Arrowslit-0.1.0.dmg](https://github.com/j4yop/arrowslit/releases/download/v0.1.0/Arrowslit-0.1.0.dmg)**.
2. Open the DMG and drag **Arrowslit** into your **Applications** folder.
3. Open Applications and double-click **Arrowslit**. macOS will show a prompt saying the developer cannot be verified yet. Click **Done**.
4. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to Arrowslit. Confirm with Touch ID or your password, then click **Open Anyway** once more.
5. Settings will open. Choose your preferred options, close the window, and Arrowslit stays live in your notch.

If you prefer Terminal, drag the app into Applications and run:

```bash
xattr -dr com.apple.quarantine "/Applications/Arrowslit.app"
open "/Applications/Arrowslit.app"
```

The download is a universal binary that runs natively on Apple Silicon (M1/M2/M3/M4) and Intel Macs.

| Release Details | |
| :--- | :--- |
| **Version** | 0.1.0 (build 7) |
| **Direct Download** | [Arrowslit-0.1.0.dmg](https://github.com/j4yop/arrowslit/releases/download/v0.1.0/Arrowslit-0.1.0.dmg) |
| **SHA-256** | `996cd86d1c860a471cd861cbc454ddb895c7846bca5c428bec91c7414cfc01ab` |
| **Homebrew Cask** | [Casks/arrowslit.rb](https://github.com/j4yop/homebrew-tap/blob/main/Casks/arrowslit.rb) |

---

## Using it

| If you want to | Do this |
| :--- | :--- |
| Open Home or a top shortcut | Click the notch strip, or hover the top center for 0.4 seconds |
| Open any other feature | Click the grid button (top right) to open the launcher |
| Customize your top tabs | Open the grid, click the pencil, and select up to three favorites |
| Start a timer or focus session | Tap a preset button or hit Focus on Home |
| Stash files or AirDrop them | Drag files onto the notch and drop them on **Tray** or **AirDrop** |
| Jot a quick note | Click Scratchpad; start typing immediately (auto-saved) |
| Copy past clipboard items | Click Clipboard, then click any card to copy it back |
| Close the workbench | Click anywhere else, move your mouse down, or press Escape |
| Open from the menu bar | Click the slit icon in your menu bar |
| Open Settings | Click the gear icon at the top right, or choose Settings from the menu bar |

---

## Things people ask

#### I installed it and nothing shows up.
Arrowslit is designed to stay out of your way. When there is nothing to show, it sits quietly in the notch. Move your mouse to the top center of the screen, or click the slit icon in your menu bar, and the workbench will slide open.

#### My Mac does not have a physical notch.
Arrowslit works on external monitors and notchless MacBooks too. It creates a virtual 160 pt notch at the top center of your display that stays hidden until you hover or click.

#### Is it private? Does it collect any data?
Arrowslit has zero network access, no telemetry, no tracking, and no user accounts. Your clipboard history, scratchpad notes, file references, and timers stay strictly on your Mac. All code is public in this repository under the GPL-3.0 license.

#### Does it store my clipboard history?
Only while Arrowslit is running, and only the last 20 plain text items in memory. Anything copied from password managers like 1Password, or marked as concealed/transient by macOS, is discarded immediately. Nothing is written to disk, and the history clears when the app quits. You can also turn off the Clipboard feature entirely in Settings.

#### Why does it ask for Camera, Calendar, or Reminders?
Only when you actually use those features. Arrowslit asks for camera permission when you open Mirror, calendar permission when you click Connect on Calendar, and reminders permission when you open Reminders. If you choose not to grant access, those specific panels stay disabled while the rest of Arrowslit continues running normally.

#### How does Now Playing work?
Arrowslit talks to macOS media services through a lightweight helper process. The helper runs in its own process, so if Apple media services ever stall or crash, Arrowslit stays fast and stable.

#### How do I remove it?
Quit Arrowslit from the menu bar or press `Cmd+Q` while in Settings, then drag Arrowslit from Applications to the Trash. If you want to clear your saved preferences and scratchpad, remove `~/Library/Preferences/com.j4yop.arrowslit.plist` and `~/Library/Application Support/Arrowslit`.

---

## Requirements

* macOS 14 (Sonoma) or newer
* Apple Silicon or Intel Mac
* Works with or without a built-in display notch

---

## Want to build it yourself?

Requires Swift 6 and Xcode 16 or newer.

```bash
# Run test suite
swift test

# Build application bundle
./Scripts/build-app.sh
open "build/Arrowslit.app"

# Build universal release DMG
UNIVERSAL=1 CONFIG=release ./Scripts/build-app.sh
SKIP_BUILD=1 ./Scripts/make-dmg.sh
```

---

## License

Arrowslit is free and open-source software licensed under the [GNU General Public License v3.0](LICENSE).
