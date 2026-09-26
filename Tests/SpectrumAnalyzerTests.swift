import XCTest
@testable import CaelestiaCore

final class SpectrumAnalyzerTests: XCTestCase {
    private let sampleRate = 48_000.0

    private func tone(_ frequency: Double, count: Int = 2048) -> [Float] {
        (0..<count).map { Float(sin(2 * .pi * frequency * Double($0) / sampleRate)) * 0.5 }
    }

    func testSilenceHasNoInventedActivity() throws {
        let result = try XCTUnwrap(SpectrumAnalyzer().consume(.init(repeating: 0, count: 2048), sampleRate: sampleRate))
        XCTAssertEqual(result.count, 64)
        XCTAssertTrue(result.allSatisfy { $0 == 0 })
    }

    func testToneAppearsInItsLogarithmicFrequencyBand() throws {
        for frequency in [250.0, 1_000.0, 6_000.0] {
            let result = try XCTUnwrap(SpectrumAnalyzer().consume(tone(frequency), sampleRate: sampleRate))
            let peak = try XCTUnwrap(result.indices.max(by: { result[$0] < result[$1] }))
            let expected = Int(log(frequency / 40) / log(16_000 / 40) * 64)
            XCTAssertLessThanOrEqual(abs(peak - expected), 2, "Frequency \(frequency) peak was \(peak), expected \(expected)")
            XCTAssertGreaterThan(result[peak], 0.3)
            XCTAssertTrue(result.allSatisfy { $0.isFinite && (0...1).contains($0) })
        }
    }

    func testChunkBoundariesDoNotChangeSpectrum() throws {
        let signal = tone(1_000)
        let contiguous = try XCTUnwrap(SpectrumAnalyzer().consume(signal, sampleRate: sampleRate))
        let analyzer = SpectrumAnalyzer()
        XCTAssertNil(analyzer.consume(Array(signal.prefix(137)), sampleRate: sampleRate))
        XCTAssertNil(analyzer.consume(Array(signal[137..<1200]), sampleRate: sampleRate))
        let chunked = try XCTUnwrap(analyzer.consume(Array(signal[1200...]), sampleRate: sampleRate))
        XCTAssertEqual(contiguous, chunked)
    }

    func testSpectrumDecaysAfterAudioStopsAndResetClearsHistory() throws {
        let analyzer = SpectrumAnalyzer()
        let active = try XCTUnwrap(analyzer.consume(tone(1_000), sampleRate: sampleRate))
        let decayed = try XCTUnwrap(analyzer.consume(.init(repeating: 0, count: 2048 * 40), sampleRate: sampleRate))
        XCTAssertGreaterThan(active.max() ?? 0, 0.3)
        XCTAssertLessThan(decayed.max() ?? 1, 0.001)
        analyzer.reset()
        let reset = try XCTUnwrap(analyzer.consume(.init(repeating: 0, count: 2048), sampleRate: sampleRate))
        XCTAssertTrue(reset.allSatisfy { $0 == 0 })
    }

    func testStereoDownmixAndIncompleteFrames() {
        XCTAssertEqual(SpectrumAnalyzer.downmix(interleaved: [1, -1, 0.5, 0.5, 99], channels: 2), [0, 0.5])
        XCTAssertEqual(SpectrumAnalyzer.downmix(interleaved: [1, 2], channels: 0), [])
    }

    func testInvalidSampleRatesDoNotEnterFFT() {
        let analyzer = SpectrumAnalyzer()
        XCTAssertNil(analyzer.consume(tone(1_000), sampleRate: 0))
        XCTAssertNil(analyzer.consume(tone(1_000), sampleRate: .nan))
    }
}
