import Accelerate
import Foundation

/// Stateful, serial-queue-only FFT. It accepts arbitrary input chunk sizes.
final class SpectrumAnalyzer {
    static let bandCount = 64
    private let size = 2048
    private let logSize: vDSP_Length = 11
    private let setup: FFTSetup
    private var window: [Float]
    private var pending: [Float] = []
    private var smoothed = [Float](repeating: 0, count: bandCount)

    init() {
        setup = vDSP_create_fftsetup(logSize, FFTRadix(kFFTRadix2))!
        window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    func reset() {
        pending.removeAll(keepingCapacity: true)
        smoothed = [Float](repeating: 0, count: Self.bandCount)
    }

    func consume(_ mono: [Float], sampleRate: Double) -> [Float]? {
        guard sampleRate > 0, sampleRate.isFinite else { return nil }
        pending.append(contentsOf: mono)
        var output: [Float]?
        var offset = 0
        while pending.count - offset >= size {
            output = analyze(Array(pending[offset..<(offset + size)]), sampleRate: sampleRate)
            offset += size
        }
        if offset > 0 { pending.removeFirst(offset) }
        return output
    }

    private func analyze(_ samples: [Float], sampleRate: Double) -> [Float] {
        var signal = [Float](repeating: 0, count: size)
        vDSP_vmul(samples, 1, window, 1, &signal, 1, vDSP_Length(size))
        var real = [Float](repeating: 0, count: size / 2)
        var imaginary = real
        var magnitudes = real
        real.withUnsafeMutableBufferPointer { realBuffer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                var split = DSPSplitComplex(realp: realBuffer.baseAddress!, imagp: imaginaryBuffer.baseAddress!)
                signal.withUnsafeBufferPointer { source in
                    source.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: size / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(size / 2))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, logSize, FFTDirection(FFT_FORWARD))
                split.imagp[0] = 0 // Nyquist is packed here, not an imaginary DC component.
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(size / 2))
            }
        }
        let low = 40.0
        let high = min(16_000.0, sampleRate * 0.48)
        guard high > low else { return smoothed }
        for band in 0..<Self.bandCount {
            let lower = low * pow(high / low, Double(band) / Double(Self.bandCount))
            let upper = low * pow(high / low, Double(band + 1) / Double(Self.bandCount))
            let start = max(1, min(size / 2 - 1, Int(lower * Double(size) / sampleRate)))
            let end = max(start + 1, min(size / 2, Int(upper * Double(size) / sampleRate)))
            let power = magnitudes[start..<end].max() ?? 0
            let amplitude = sqrt(power) / Float(size)
            let decibels = 20 * log10(max(amplitude, 0.000_001))
            let normalized = min(1, max(0, (decibels + 65) / 60))
            let factor: Float = normalized > smoothed[band] ? 0.72 : 0.18
            smoothed[band] += (normalized - smoothed[band]) * factor
        }
        return smoothed
    }

    static func downmix(interleaved samples: [Float], channels: Int) -> [Float] {
        guard channels > 0 else { return [] }
        return stride(from: 0, to: samples.count - samples.count % channels, by: channels).map { offset in
            var sum: Float = 0
            for channel in 0..<channels { sum += samples[offset + channel] }
            return sum / Float(channels)
        }
    }
}
