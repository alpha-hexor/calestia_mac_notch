# Caelestia Notch

A native macOS notch companion inspired by **Caelestia Shell**: warm cream,
peach cards, terracotta accents, circular music visualization, and Bongo Cat.
Built for your M4 Mac with SwiftUI + AppKit. Requires **macOS 14+ and Xcode 16+**.
No Homebrew, API keys, Swift packages, or paid developer account needed to run locally.

## Open and run in Xcode

1. Quit **Boring Notch** first so the two notch windows do not overlap.
2. Open **`CaelestiaNotch.xcodeproj`** from this folder. Open the project, not
   `Package.swift` (the package is only for audio-math tests).
3. In Xcode's top toolbar, choose **CaelestiaNotch → My Mac**.
4. Press **⌘R** or click the triangular Run button.
5. Move your pointer to the top-center camera notch. The panel expands on hover
   and closes about half a second after your pointer leaves.

This is a menu-bar app: **there is no Dock icon or normal app window**. Find the
moon-and-stars icon in your menu bar for **Show Notch**, permissions, audio controls,
credits, and Quit. On a monitor without a notch, it creates a compact top-center strip.

### Connect Spotify

1. Open the **Spotify desktop app** and play a song.
2. Allow the macOS prompt that lets **Caelestia Notch control Spotify**.
3. Open the Media tab. Artwork, metadata, transport, and the seek slider use your
   installed Spotify app directly; there is no Spotify login inside this app.

If you denied access, go to **System Settings → Privacy & Security → Automation**,
enable Spotify under Caelestia Notch, then use **Retry Spotify Connection** in the
menu bar. The player also shows a Settings/Retry action when denied.

### Enable the real music visualizer

1. In Media, click **Enable visualizer**.
2. Allow **Screen & System Audio Recording** access when macOS asks. The exact
   category wording depends on your macOS version.
3. If macOS requests a restart, quit and reopen the **same app copy**, then click
   **Enable visualizer** again. Permission approval and starting capture are separate.
   You can also use the menu-bar **Audio Capture Settings…** shortcut.

### Permission is enabled, but capture still fails

Debug and Release now have separate privacy identities:
- **Caelestia Notch** — standalone Release app, `dev.personal.caelestianotch`.
- **Caelestia Notch Debug** — Xcode Debug app, `dev.personal.caelestianotch.debug`.

The original build used the same ID for both, causing macOS to associate permission
with a different local signature. A Settings toggle could appear enabled while
capture was rejected. To recover an old entry:

1. Quit all copies of the app.
2. In **System Settings → Privacy & Security → Screen & System Audio Recording**,
   remove the old Caelestia entry using **−**, then use **+** to add the exact app
   you want to run. Choose **Screen & System Audio Recording**, not audio-only;
   this ScreenCaptureKit implementation needs the screen-capture permission.
3. For the standalone version, select
   `build/Build/Products/Release/Caelestia Notch.app` in this project.
4. Open that same app, play Spotify, and click **Enable visualizer** again.

The menu's **Show Running App in Finder** reveals the exact copy. If capture fails,
**Details** in the Media footer displays the underlying error, build name, and path.
An ad-hoc-signed binary can still require reapproval after rebuilding that same
configuration; using a development signing certificate makes identity more stable.

The visualizer uses **actual system audio**, analyzed with a 2,048-sample FFT and
64 logarithmic frequency bands. Other apps' sounds can affect the bars. It does
not access your microphone, save audio, upload audio, or process screen images.
The OS may show a recording indicator while capture is enabled.

Audio capture is opt-in each launch. Disable it at any time from the menu bar.
The spectrum settles to zero on silence. The ring and Bongo Cat pause with Spotify.

### Beat-reactive Bongo Cat

The cat switches between the GIF's two poses on detected bass/drum pulses, with
a small, eased settling movement. It holds still between hits instead of looping
the original ten pose changes per second. A 320 ms cooldown caps tapping at about
three times per second. Both tabs share the same pose and beat detection.

Enable the audio visualizer for this behavior. Silence, paused Spotify, and capture
being off keep the cat still. Detection follows low-frequency pulses in system
audio, not an exact BPM grid; other apps' sounds can also trigger it while Spotify
is playing. Reduce Motion disables the extra compression/settle effect.

## What's included

| Tab | Features |
| --- | --- |
| Dashboard | Clock, current-month calendar, battery/charging, hardware model, uptime, mini Spotify player |
| Media | Circular album art, live radial frequency bars, title/artist/album, previous/play/pause/next, seeking, animated Bongo Cat |
| Performance | CPU utilization, memory-used estimate, used/available disk space |

The selected tab is remembered. The panel follows display configuration changes
and prefers the display with a physical notch. The collapsed notch shows artwork
and a tiny live spectrum when capture is enabled.

Memory is an estimate from active, wired, compressed, and purgeable pages; it is
not Apple's memory-pressure score. Storage uses filesystem free capacity, so it
can differ from the purgeable-inclusive number in System Settings. CPU/memory
update every two seconds; disk/battery every thirty seconds. No temperatures,
weather, GPU gauge, workspace tab, or automatic launch at login in this version.

## Build from Terminal (optional)

Run these commands from this project folder. Using `DEVELOPER_DIR` fixes the
Command Line Tools selection for these commands only:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project CaelestiaNotch.xcodeproj -scheme CaelestiaNotch \
  -configuration Debug -derivedDataPath build build

open "build/Build/Products/Debug/Caelestia Notch.app"
```

For a standalone optimized build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project CaelestiaNotch.xcodeproj -scheme CaelestiaNotch \
  -configuration Release -derivedDataPath build build
```

You can drag `build/Build/Products/Release/Caelestia Notch.app` into Applications.
Run one copy at a time. Prefer a stable location for macOS permission grants.

### Signing

The project uses **Sign to Run Locally** (ad-hoc signing), with the Apple Events
entitlement and no App Sandbox. A paid Apple developer subscription is unnecessary
for this local build. If Xcode asks for signing, select the project → CaelestiaNotch
target → Signing & Capabilities → **Signing Certificate: Sign to Run Locally**.
For more stable identity across builds, you can instead enable automatic signing
and select your own team. Local rebuilds may require permission approval again.
This project is not configured for App Store distribution or notarization.

## Verification

Audio analysis tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Tests exercise silence, tones in different frequency bands, sample chunk boundaries,
stereo downmix, decay/reset, invalid sample rates, beat cooldown, pause/capture gating,
and synthetic kick drums passed through the actual FFT. See [manual QA](docs/manual-qa.md)
for the checks that require macOS UI permissions and your Spotify session.

After building both Debug and Release, verify their signatures and separate privacy
identities with `python3 scripts/check-app-identities.py`.

## Where to customize

```text
CaelestiaNotch/
  App/          App lifecycle, shared state, menu-bar controls
  Window/       Notch positioning, hover detection, collapse delay
  Services/     Spotify, ScreenCaptureKit audio, cat motion, system metrics
  Core/         Independent FFT, beat detection, playback gating
  UI/           Theme, three tabs, circular visualizer, GIF renderer
  Resources/    Bongo Cat GIF and upstream attribution/license
Config/         Info.plist, Apple Events entitlement
Tests/          Audio-analysis tests
```

- **Colors:** `UI/Theme.swift` → `Palette`.
- **Size and hover delay:** `Window/NotchWindowController.swift`.
- **Tab layouts:** `UI/DashboardView.swift`, `MediaView.swift`, `PerformanceView.swift`.
- **Visualizer response:** `Core/SpectrumAnalyzer.swift`.
- **Cat sensitivity/cooldown:** `Core/BeatDetector.swift`; settling effect in `UI/BongoCatView.swift`.

Bongo Cat is the character in the linked Caelestia GIF (rather than Kirby).
The bundled GIF is unmodified; upstream source and GPL license are included in
`CaelestiaNotch/Resources/`. This is an unofficial app inspired by Caelestia Shell.
