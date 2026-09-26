# Single-line synchronized lyrics

Approved placement: Media tab only, directly beneath song information and above
playback controls. Exactly one line, using the existing cream/terracotta theme.

## Reference and approach
Boring Notch's `dev` branch uses LRCLIB, parses timestamped LRC lyrics, caches
lookups, and selects lines against interpolated player time on a 250 ms UI tick.
References reviewed: `managers/LyricsService.swift`, `managers/MusicManager.swift`,
and `components/Notch/NotchHomeView.swift` at commit
`28aa4668dcaa5025132d0f0248fefb810fcc1a54`. Implement the same general approach
independently, using our existing Spotify desktop integration.

## Behavior
- Read track metadata and playback position from Spotify; fetch timed lyrics from
  LRCLIB over HTTPS. No Spotify web login or audio-capture permission is required.
- Try exact title/artist/album/duration lookup, then title+artist search. Reject
  mismatched artists, titles, or track durations rather than displaying a wrong
  version. Prefer timestamped lyrics; never invent timings for plain lyrics.
- Show one line, centered in terracotta, with a short fade on change. Long lines
  stay single-line, slightly shrink and then truncate; tooltip exposes full text.
- Interpolate position between Spotify's existing one-second polls, refreshing
  the visible line every 200 ms. Pause holds the line; seeks rebase immediately;
  old in-flight polls cannot overwrite a newer seek. Stop extrapolating after two
  seconds without a valid poll, avoiding runaway lyrics on connection failures.
- Preserve blank timestamp entries for instrumental gaps, and show a music-note
  placeholder before the first line. Loading, instrumental, unavailable, and
  retryable network-failure states use the same reserved line height.
- Keep an in-memory bounded cache; cancel superseded requests and reject stale
  results after a track change. Track metadata is sent to LRCLIB, not audio.

## Components / implementation
1. Core LRC parser/timeline, playback clock, and LRCLIB client with a transport seam.
2. Main-actor lyrics service subscribes to distinct Spotify track changes.
3. Media lyric row observes lyrics and interpolated playback; other tabs unchanged.
4. Tests cover timestamps, blank gaps, first/last line, seek/pause, matching, cache,
   HTTP errors, fallback lookup, and query encoding using synthetic test lyrics.
5. Build Debug and Release, verify their separate identities, and restart the
   user's running Release app. No commit unless requested.

Review: fixed placement and fallback states; independent of audio capture; no
additional UI tabs, plain-lyrics auto-scrolling, or lyric text committed as fixtures.
