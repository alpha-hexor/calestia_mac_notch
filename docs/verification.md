# Verification — 2026-09-20

Environment: Apple Silicon Mac, macOS 26.6.2, Xcode 27.0.

## Passed
- Xcode Debug build (arm64 and x86_64 compilation).
- Xcode Release build for My Mac / arm64.
- Six XCTest audio-analysis tests, zero failures:
  - silence stays at zero;
  - 250 Hz, 1 kHz, and 6 kHz tones localize to the expected bands;
  - split audio buffers produce the same spectrum as a contiguous buffer;
  - bars decay after silence and reset clears history;
  - stereo downmix handles opposite channels and incomplete frames;
  - invalid sample rates do not enter the FFT.
- Info.plist, entitlement file, and Xcode project pass `plutil -lint`.
- Debug and Release bundles pass strict `codesign --verify`.
- GIF, attribution, and upstream GPL text are present in the built bundle.
- Release executable startup smoke check: stayed running for five seconds with
  no console errors or early exit; the test instance was then stopped.

## Still interactive
The startup smoke check is not an end-to-end UI test. Hover/layout inspection,
Spotify authorization and transport, recording permission and live capture,
multi-display/full-screen behavior, and resource usage need the user's desktop
session. Follow `manual-qa.md`; these checks are not marked as passed.

## Visualizer permission repair

The user's attempts at 21:06:20 and 21:06:24 were rejected before stream creation.
`replayd` logged `TCC Disallow`; `tccd` logged `Failed to match existing code
requirement` for `dev.personal.caelestianotch` and `kTCCServiceScreenCapture`.
The logs identify Debug and Release executables sharing the bundle ID but using
different ad-hoc code hashes. Settings had selected the Debug bundle when the
permission toggle was enabled. This establishes a signing/authorization failure,
not an FFT failure.

Regression check: `python3 scripts/check-app-identities.py` failed against the
original bundles. After assigning Debug its own bundle ID and display name, both
configurations rebuilt and the check passed, including strict signature validation.

Both corrected bundles were registered with LaunchServices. Only the Release
app's stale ScreenCapture authorization was reset using the supported `tccutil`
command. The user must grant capture again; no permissions were bypassed or
granted programmatically. The source audio-processing path was not changed.

The live-capture retest remains blocked on that user authorization. An automated
identity check prevents the demonstrated Debug/Release collision; it does not
simulate TCC or prove that captured audio reaches the visualizer after approval.

Follow-up: the user confirmed that live capture works after adding the correct
app copy in Settings.

## Beat-reactive Bongo Cat

The source GIF was inspected: two frames at 100 ms each (10 pose changes/second).
The replacement uses shared audio-driven pose changes, a 320 ms retrigger limit,
and a small settle effect. It no longer runs a wall-clock GIF loop.

All 11 Core tests passed, including five new beat/rhythm tests. Synthetic 85 Hz
kick drums over a sustained 440 Hz tone, at 80, 120, and 160 BPM, each produced
one tap per kick through the real 2,048-sample FFT, within 150 ms of the onset.
Other tests cover sustained notes/silence, cooldown under rapid triggers, treble
rejection, and pose preservation across playback/capture stops and restarts.
These tests verify detection/gating, not the subjective appearance on real music.

## Single-line lyrics — 2026-09-26

- Debug and Release builds succeeded; app identity/signature checks passed.
- Full Core suite passed: 23 tests (11 existing audio/rhythm tests plus 12 lyrics
  tests). The 12 lyrics tests passed again after fixing literal-plus query encoding.
- Coverage includes fractional/multiple timestamps, Unicode, blank gaps, offsets,
  boundary selection and backward seeking, paused/stale playback clocks, exact and
  fallback matching, mismatched recordings, instrumentals, plain-only results,
  cache isolation, request encoding, and retryable HTTP errors.
- A live request through the actual LRCLIB client returned 34 timestamped lines
  for the reference recording. The diagnostic printed counts/timing only; lyric
  content was not saved as a fixture. The temporary diagnostic source was removed.
- The user independently ran the app from Xcode and confirmed it is working.
  The Release bundle was also rebuilt. Detailed edge-case checks remain listed
  in `manual-qa.md`, rather than being inferred from that confirmation.
