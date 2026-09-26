# Interactive verification

Build and FFT tests can run without permissions. The following checks need a
logged-in Mac desktop, Spotify, and user approval of macOS permission prompts.
These are a checklist, not a claim that the interactive checks have passed.

## Window and layout
- Quit Boring Notch; run Caelestia Notch. Confirm menu-bar icon and no Dock icon.
- Hover over the notch: cream panel expands below the camera, with three tabs.
- Move between the notch, tabs, slider, and panel edges without unexpected closing.
- Move outside: closes after ~450 ms. Quickly re-enter: closing is canceled.
- Click the desktop below the closed notch: click reaches the underlying app.
- Switch tabs, quit, relaunch: selected tab is restored.
- Verify calendar on a six-week month, narrow display scaling, light/dark OS modes.
- Connect/disconnect an external display; check position on notched and non-notched screens.
- Check other Spaces and a full-screen app; macOS full-screen/menu-bar behavior can vary.

## Spotify
- Spotify closed: empty state and Open Spotify action.
- Spotify running: approve Automation; check title, artist, album, cover, duration.
- Previous, pause, play, next, and seeking work, including seeking while paused.
- Track changes update artwork; a missing/network-failed cover shows a placeholder.
- Bongo Cat changes pose on bass/drum pulses while Spotify plays and capture is on.
  Check slow and fast tracks: no free-running GIF, no rapid-fire tapping, and still
  poses between hits. Pause or disable capture: the cat settles and stays still.
- Switch Media → Dashboard → Media while playing: the pose and beat response are
  shared, without restarting a loop or replaying old beats. With Reduce Motion
  enabled, pose changes remain but the extra compression/settle is disabled.
- Deny Automation: readable state, Settings and Retry available, no repeated prompts.
- Quit/reopen Spotify: no stale playback, connection recovers.

## Audio
- No audio-capture request until Enable visualizer is pressed.
- Approve capture; play bass-heavy then treble-heavy audio: different bands respond.
- Pause Spotify: ring and cat stop; resume: react again.
- Mute/stop system audio: bars settle rather than remaining stuck.
- Deny capture: Spotify transport still works; Settings/Retry remain usable.
- Build both configurations. Confirm Privacy settings distinguish Caelestia Notch
  from Caelestia Notch Debug; granting one must not authorize or overwrite the other.
- Upgrade an old build with a stale grant: remove/re-add the exact app in Privacy
  settings, relaunch that copy, Enable visualizer, and confirm audio arrives.
- Capture failure → Details shows the actual error and running app path; Show
  Running App in Finder reveals the same executable bundle.
- Disable capture: system recording indicator clears and bars reset.
- Re-enable capture, sleep/wake, and disconnect display: recover or show a retry state.
- Check headphones and speakers. Capture is system-wide, not microphone-based.

## Metrics and resources
- CPU changes under load; memory and storage display plausible numbers.
- Battery status works on a laptop; desktop displays AC power.
- Inspect Activity Monitor with panel closed/open and capture off/on for sustained
  unexpected CPU growth or memory accumulation.

## Single-line lyrics
- Play a track with LRCLIB synced lyrics: exactly one line appears below the song
  information and above controls in Media; no changes to Dashboard or Performance.
- Pause/resume in Spotify and in the notch: the line holds and resumes correctly.
- Seek backward/forward, including while paused: the correct line appears without
  an old in-flight poll snapping it back.
- Switch tracks rapidly during a lookup: old lyrics do not overwrite the new track.
- Long and non-Latin lines remain one line without pushing the player controls or
  cat out of position. Hover exposes the full text.
- Intros/timestamped gaps show a music note; instrumentals and missing synced
  lyrics use their respective labels instead of guessing timing for plain text.
- Disconnect the network for an uncached track: inline Retry appears and works
  after connectivity returns. A previously cached track still displays lyrics.
- Lyrics work with audio capture disabled. Close/reopen the panel and switch tabs:
  playback synchronization resumes from the current position.
