# Beat-reactive Bongo Cat

Approved in conversation: replace the frantic free-running GIF with gentler,
beat-reactive movement in both Media and Dashboard.

## Behavior
The bundled GIF contains only two poses, each with a 100 ms delay. Looping it
currently changes poses ten times per second, independently of the music.
Instead, advance one pose per detected bass/drum onset and hold that pose between
hits. Add a small, brief compression and settle on each hit. Enforce at least
320 ms between accepted hits (about three taps per second maximum). Silence,
paused Spotify, and inactive capture leave the cat still. There is no decorative
fallback loop and no claim of exact BPM tracking.

## Integration
Reuse the existing 64-band spectrum. A pure detector measures positive spectral
changes in the low 24 bands (roughly 40–380 Hz for the existing 48 kHz capture),
with an adaptive threshold, noise floor, rearming, and cooldown. A shared controller
combines spectrum, Spotify playback, and capture state. Both views observe the
same pose count, preventing tab switches from restarting or fabricating motion.
The GIF decoder continues to use the original, unmodified asset; wall-clock GIF
looping is removed. Existing capture, permissions, and radial visualization remain
the same.

## Verification and implementation
1. Implement detector and rhythm state as testable Core types.
2. Connect a shared controller to the existing observable services.
3. Render discrete poses and a short eased settle in both tabs.
4. Test silence, sustained notes, isolated/regular pulses, high-rate retriggers,
   real synthetic PCM through the existing FFT, and pause/capture gating.
5. Build both configurations and check their separate signed identities. Relaunch
   only the running app copy; macOS may require reapproval for a rebuilt ad-hoc app.

Review: no new permissions, API keys, assets, independent tab clocks, or BPM API.
