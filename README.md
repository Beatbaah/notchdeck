# NotchDeck

A menu bar utility for MacBooks that turns the camera notch into a panel. Move the pointer onto the
notch and it opens. Move away and it closes.

On a Mac without a notch, it draws a black pill of the same size in the middle of the menu bar.

## What it does

| Tab | Features |
| --- | --- |
| **Home** | Now playing from **Music** or **Spotify** (artwork, title, artist, previous/play-pause/next). Countdown **timer** with 1/5/15/25-minute presets: when it finishes, a sound plays and the notch opens. **Volume** slider, mute, battery level, sleep display. |
| **Shelf** | Drag files from Finder onto the notch to hold them, then drag them out to Mail, Slack, a folder, etc. Double-click to open, right-click to reveal in Finder. It stores only references, so your files are never moved or copied. |
| **Clipboard** | The last 40 snippets of copied text. Click one to copy it again. History is kept in memory only. Items that password managers mark as secret are skipped. |
| **Notes** | A scratch pad that saves as you type. |
| **Apps** | Pinned app launcher. Click **+** to add an app; right-click an app to remove it. |

While the notch is closed, it widens slightly to show a **live activity**:
- **Music playing:** album artwork on the left, animated bars on the right.
- **Timer running:** the time remaining.

The gear icon (top right of the open notch) has **Launch at Login** and **Quit**. There's also a small
menu bar icon with **Open Notch** and **Quit**.

## Build and install

Requires macOS 13 Ventura or later and Xcode (or the Command Line Tools: `xcode-select --install`).

```bash
cd NotchDeck
./build.sh
cp -R build/NotchDeck.app /Applications/
open /Applications/NotchDeck.app
```

You can also open `Package.swift` in Xcode and press Run. The `build.sh` route is better, though,
because it wraps the binary in a proper `.app` with the `Info.plist`. Music control permission and
Launch at Login need that.

### Permissions

- **Automation (Music / Spotify):** the first time a player is open, macOS asks whether NotchDeck
  may control it. Click **OK**. To change this later, go to System Settings → Privacy & Security →
  Automation.
- Nothing else is needed. Notch hover works by polling the pointer position, so there's no
  Accessibility prompt.

`build.sh` signs with your **Apple Development** certificate if this Mac has one, so the Automation
permission survives rebuilds. To get one for free: Xcode → Settings → Accounts → add your Apple ID →
Manage Certificates → **+** → Apple Development. Without it the build is signed ad hoc, and macOS may ask
for Automation again after each rebuild. If Gatekeeper
blocks the first launch, right-click the app → **Open**.

## Project layout

```
Sources/NotchDeck/
  App/     entry point, app delegate, notch window controller, shared state, AppleScript helper
  Models/  music, timer, clipboard, file shelf, app launcher, system (volume/battery)
  Views/   SwiftUI views for the closed notch, the open panel and each tab
Support/Info.plist
build.sh
```

## Known limits

- Only Music and Spotify are supported for now-playing. Browser audio and other players aren't
  read, because macOS no longer offers a public, system-wide now-playing API to third-party apps.
- Lyrics and calendar aren't included yet.
- Brightness and Do Not Disturb have no public API, so they aren't in the System card.
