# NotchDeck

*Your MacBook notch shouldn't stay idle.*

A menu bar utility for MacBooks that turns the camera notch into a panel. Move the pointer onto the
notch and it opens. Move away and it closes.

On a Mac without a notch, it draws a black pill of the same size in the middle of the menu bar.

## What it does

| Tab | Features |
| --- | --- |
| **Home** | Now playing from **Music**, **Spotify**, **VLC**, or a web player in **Safari**, **Chrome**, **Brave** or **Edge** (artwork, title, artist, previous/play-pause/next). With nothing playing, it shows your **next event** today instead. **Volume** slider, mute, battery level, sleep display. |
| **Calendar** | Today's and tomorrow's events (all-day first), with times, place and calendar colour. Click one to open Calendar. |
| **Shelf** | Drag files from Finder onto the notch to hold them, then drag them out to Mail, Slack, a folder, etc. Double-click to open, right-click to reveal in Finder. It stores only references, so your files are never moved or copied. |
| **Clipboard** | The last 40 snippets of copied text. Click one to copy it again. History is kept in memory only. Items that password managers mark as secret are skipped. |
| **Notes** | A scratch pad that saves as you type. |
| **Apps** | Pinned app launcher. Click **+** to add an app; right-click an app to remove it. |

While music plays and the notch is closed, it widens slightly to show a **live activity**:
- **Music playing:** album artwork on the left, animated bars on the right.
- **New track:** the notch grows down for a few seconds to show the title and artist, like an iPhone's
  Dynamic Island.

It moves like the Dynamic Island too: the closed notch swells as the pointer arrives, the panel stretches
open with a soft bounce, and its content settles in a moment later.

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
- **Calendar:** asked only when you press **Show my calendar** on the Calendar tab.
- **Media from browsers:** off by default. Turn it on in the gear menu, then in each browser turn on
  **Allow JavaScript from Apple Events** (Safari: Develop menu; Chrome, Brave, Edge: View → Developer).
  NotchDeck checks tabs on known media sites (YouTube, SoundCloud, Spotify Web, Apple Music, Audiomack,
  Boomplay, Deezer, Tidal, Mixcloud, Twitch, Vimeo) and the active tab of the front window.
- Nothing else is needed. Notch hover works by polling the pointer position, so there's no
  Accessibility prompt.

`build.sh` signs with your **Apple Development** certificate if this Mac has one, so the Automation
permission survives rebuilds. To get one for free: Xcode → Settings → Accounts → add your Apple ID →
Manage Certificates → **+** → Apple Development. Without it the build is signed ad hoc, and macOS may ask
for Automation again after each rebuild. If Gatekeeper
blocks the first launch, right-click the app → **Open**.

## Keyboard shortcut

**⌃⌥N** opens or closes the notch from anywhere. Opening NotchDeck again while it's running opens the
panel of the copy that's already running.

## Project layout

```
Sources/NotchDeck/
  App/     entry point, app delegate, notch window controller, shared state, AppleScript helper
  Models/  music, calendar, clipboard, file shelf, app launcher, system (volume/battery)
  Views/   SwiftUI views for the closed notch, the open panel and each tab
Support/Info.plist, AppIcon.icns
tools/make-icon.swift   redraws the app icon (see the comment at its top)
build.sh
```

## Known limits

- Now playing covers the players above only. Other apps (Podcasts, desktop YouTube Music, Audible…) can't be read,
  because macOS offers no public, system-wide now-playing API to third-party apps.
- Lyrics aren't included.
- Brightness and Do Not Disturb have no public API, so they aren't in the System card.

## Licence

MIT, see [LICENSE](LICENSE).
