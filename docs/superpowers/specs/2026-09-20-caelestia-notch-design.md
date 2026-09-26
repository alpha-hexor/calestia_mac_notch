# Caelestia Notch — approved design

Native personal macOS 14+ app for Apple Silicon, built with SwiftUI and AppKit.
Approved in conversation; user requested direct implementation after design approval.

## Experience
- Black compact notch at the top of the built-in display (main display fallback).
- Hover expands a warm cream, peach, and terracotta panel; leaving collapses after 450 ms.
- Exactly Dashboard, Media, and Performance tabs; selected tab persists.
- Dashboard: clock, calendar, battery, hardware model, uptime, Spotify summary.
- Media: artwork, 64 radial frequency bars, Spotify metadata and transport/seek,
  and Caelestia's Bongo Cat GIF (playing only while Spotify plays).
- Performance: live CPU utilization, used memory, and disk capacity gauges.
- Menu-bar access to show panel, audio capture, permissions, and quit.

## Architecture and data
- AppKit nonactivating panel owns positioning and pointer tracking; SwiftUI owns UI.
- Spotify service executes serialized AppleScript off the main thread, polls once
  per second, downloads artwork asynchronously, and handles permission denial.
- Audio service uses ScreenCaptureKit system audio, no microphone. Captured samples
  feed a Hann-windowed FFT on a serial queue. No recordings are stored. Permission
  is requested by an explicit Enable Visualizer action, never automatically on launch.
- System monitor reads public Mach, filesystem, and IOKit power-source APIs.
- Independent services publish UI state on the main actor. Idle/paused rendering
  stops. Capture can be disabled from the menu bar.

## Boundaries and failure states
Spotify desktop is required; no web API credentials. Closed Spotify offers Open
Spotify. Denied Automation permission offers settings and retry. Denied capture
leaves playback usable with inactive bars. System audio may include other apps.
No weather, temperatures, GPU metrics, workspace tab, or launch-at-login in v1.
Panel follows display reconfiguration and works with a synthetic notch on a display
without one. Physical camera area is kept black and controls sit below it.

## Verification
Build the macOS app with installed Xcode. Test FFT silence, tone localization,
stereo downmix, and decay. Document manual checks for hover, screen changes,
Spotify commands, capture permission, animated GIF, and system gauges.

## Implementation sequence
1. Scaffold native application, Xcode project, theme, and notch panel.
2. Implement Spotify service and system monitor.
3. Implement audio capture, FFT, and radial rendering.
4. Build three tabs and package attributed Bongo Cat asset.
5. Build, run focused core tests, and provide beginner setup/manual QA guide.
