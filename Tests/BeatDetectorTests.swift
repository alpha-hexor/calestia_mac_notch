import XCTest
@testable import CaelestiaCore

final class BeatDetectorTests: XCTestCase {
    private func spectrum(bass: Float, treble: Float = 0) -> [Float] {
        Array(repeating: bass, count: 24) + Array(repeating: treble, count: 40)
    }

    func testSilenceAndSteadyNotesDoNotCauseContinuousTapping() {
        for level: Float in [0, 0.04, 0.8] {
            var detector = BeatDetector()
            for frame in 0..<300 {
                XCTAssertNil(detector.consume(bands: spectrum(bass: level), at: Double(frame) / 30))
            }
        }
    }

    func testAnIsolatedHitProducesOneTapNotAnAnimationLoop() {
        var detector = BeatDetector()
        XCTAssertNil(detector.consume(bands: spectrum(bass: 0), at: 0))
        XCTAssertNotNil(detector.consume(bands: spectrum(bass: 0.8), at: 0.1))
        for frame in 4..<180 {
            let level: Float = frame < 45 ? 0.8 : 0
            XCTAssertNil(detector.consume(bands: spectrum(bass: level), at: Double(frame) / 30))
        }
    }

    func testFastRetriggersAreLimitedAndTrebleDoesNotDriveTheCat() {
        var detector = BeatDetector()
        var hits: [Double] = []
        for frame in 0..<180 {
            let time = Double(frame) / 30
            if detector.consume(bands: spectrum(bass: frame % 3 == 1 ? 0.9 : 0), at: time) != nil {
                hits.append(time)
            }
        }
        XCTAssertGreaterThan(hits.count, 5)
        XCTAssertLessThan(hits.count, 20)
        for (previous, next) in zip(hits, hits.dropFirst()) {
            XCTAssertGreaterThanOrEqual(next - previous, BeatDetector.minimumInterval)
        }

        detector.reset()
        for frame in 0..<90 {
            XCTAssertNil(detector.consume(bands: spectrum(bass: 0, treble: frame % 10 == 1 ? 1 : 0), at: Double(frame) / 30))
        }
    }

    func testRegularKickDrumsThroughTheRealFFTProduceOneTapPerBeat() {
        // Exercise the actual smoothed FFT output rather than only idealized bands.
        let rate = 48_000.0
        let chunkSize = 2048
        for interval in [0.375, 0.5, 0.75] {
            let analyzer = SpectrumAnalyzer()
            var detector = BeatDetector()
            var hits: [Double] = []
            let expected = (0..<8).map { 0.5 + Double($0) * interval }
            let duration = expected.last! + interval
            let chunks = Int(duration * rate) / chunkSize
            for chunk in 0..<chunks {
                let samples = (0..<chunkSize).map { index -> Float in
                    let time = Double(chunk * chunkSize + index) / rate
                    var kick = 0.0
                    if time >= 0.5 {
                        let age = (time - 0.5).truncatingRemainder(dividingBy: interval)
                        kick = sin(2 * .pi * 85 * time) * exp(-age / 0.045) * 0.7
                    }
                    return Float(kick + sin(2 * .pi * 440 * time) * 0.025)
                }
                let time = Double((chunk + 1) * chunkSize) / rate
                if let bands = analyzer.consume(samples, sampleRate: rate), detector.consume(bands: bands, at: time) != nil {
                    hits.append(time)
                }
            }
            XCTAssertEqual(hits.count, expected.count, "Interval \(interval): detected \(hits)")
            for (hit, beat) in zip(hits, expected) {
                XCTAssertGreaterThanOrEqual(hit, beat)
                XCTAssertLessThan(hit - beat, 0.15, "Tap should follow a beat promptly")
            }
        }
    }

    func testPauseAndCaptureStopHoldThePoseAndDoNotReplayOldBeats() {
        var rhythm = BongoRhythm()
        for frame in 0..<30 {
            _ = rhythm.update(bands: spectrum(bass: frame % 6 == 1 ? 0.8 : 0), at: Double(frame) / 30, isPlaying: true, isCapturing: true)
        }
        let beforePause = rhythm.beatCount
        XCTAssertGreaterThan(beforePause, 0)
        for frame in 30..<60 {
            XCTAssertNil(rhythm.update(bands: spectrum(bass: frame % 6 == 1 ? 0.8 : 0), at: Double(frame) / 30, isPlaying: false, isCapturing: true))
        }
        XCTAssertEqual(rhythm.beatCount, beforePause)
        for frame in 60..<90 {
            XCTAssertNil(rhythm.update(bands: spectrum(bass: frame % 6 == 1 ? 0.8 : 0), at: Double(frame) / 30, isPlaying: true, isCapturing: false))
        }
        XCTAssertEqual(rhythm.beatCount, beforePause)
        XCTAssertNil(rhythm.update(bands: spectrum(bass: 0.8), at: 3, isPlaying: true, isCapturing: true))
        XCTAssertNil(rhythm.update(bands: spectrum(bass: 0), at: 3.1, isPlaying: true, isCapturing: true))
        XCTAssertNotNil(rhythm.update(bands: spectrum(bass: 0.8), at: 3.2, isPlaying: true, isCapturing: true))
        XCTAssertEqual(rhythm.beatCount, beforePause + 1)
    }
}
