import Foundation

/// An atomic position sample for smooth lyrics between Spotify's one-second polls.
struct PlaybackClock: Sendable {
    var trackID: String?
    var position: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying = false
    var sampledAt: TimeInterval = 0

    func position(at time: TimeInterval) -> TimeInterval {
        guard position.isFinite, duration.isFinite, duration > 0 else { return 0 }
        let elapsed = time.isFinite && sampledAt.isFinite ? max(0, time - sampledAt) : 0
        // A stalled/failed Spotify request must not advance lyrics indefinitely.
        let progress = isPlaying ? min(elapsed, 2) : 0
        return min(duration, max(0, position + progress))
    }
}
