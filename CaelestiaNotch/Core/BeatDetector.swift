import Foundation

/// Detects low-frequency onsets in the same normalized spectrum used by the ring.
/// This is pulse detection, not a BPM estimator; a sustained loud note is not a beat.
struct BeatDetector {
    static let minimumInterval: TimeInterval = 0.32
    private static let bassBandCount = 24
    private var previous: [Float]?
    private var lastSampleTime: TimeInterval?
    private var lastBeatTime: TimeInterval?
    private var averageFlux: Float = 0
    private var fluxVariance: Float = 0
    private var armed = true

    mutating func reset() { self = BeatDetector() }

    /// Returns the strength of a new hit, or nil. Call with a monotonic timestamp.
    mutating func consume(bands: [Float], at time: TimeInterval) -> Double? {
        guard bands.count == SpectrumAnalyzer.bandCount, time.isFinite else { return nil }
        let bass = bands.prefix(Self.bassBandCount).map { $0.isFinite ? min(1, max(0, $0)) : 0 }
        guard let previous, let lastSampleTime else {
            self.previous = bass
            self.lastSampleTime = time
            return nil // Connecting in the middle of a note should not invent a hit.
        }
        guard time > lastSampleTime else { return nil }

        let energy = bass.reduce(0, +) / Float(Self.bassBandCount)
        let flux = zip(bass, previous).reduce(Float(0)) { $0 + max(0, $1.0 - $1.1) } / Float(Self.bassBandCount)
        let threshold = max(0.018, averageFlux * 1.6 + sqrt(fluxVariance) * 0.5)
        if flux < threshold * 0.55 { armed = true }

        let outsideCooldown = lastBeatTime.map { time - $0 >= Self.minimumInterval } ?? true
        let isHit = armed && outsideCooldown && energy > 0.10 && flux > threshold

        // Update the background *after* testing the onset so a hit cannot mask itself.
        let alpha = Float(1 - exp(-min(time - lastSampleTime, 0.25) / 0.75))
        let difference = flux - averageFlux
        averageFlux += alpha * difference
        fluxVariance += alpha * (difference * difference - fluxVariance)
        self.previous = bass
        self.lastSampleTime = time

        guard isHit else { return nil }
        armed = false
        lastBeatTime = time
        return Double(min(1, max(0.25, energy / 0.7)))
    }
}

/// Playback/capture gating is shared by both cat views, independent of their lifetime.
struct BongoRhythm {
    private var detector = BeatDetector()
    private(set) var beatCount: UInt = 0

    mutating func update(bands: [Float], at time: TimeInterval, isPlaying: Bool, isCapturing: Bool) -> Double? {
        guard isPlaying, isCapturing else {
            detector.reset()
            return nil
        }
        guard let strength = detector.consume(bands: bands, at: time) else { return nil }
        beatCount &+= 1
        return strength
    }
}
