import AppKit
import Combine
import ScreenCaptureKit
import CoreMedia
import AVFoundation

private final class AudioStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let analyzer = SpectrumAnalyzer()
    private var lastPublish: CFAbsoluteTime = 0
    var onSpectrum: (([Float]) -> Void)?
    var onFailure: ((Error) -> Void)?

    func stream(_ stream: SCStream, didStopWithError error: Error) { onFailure?(error) }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid,
              let description = sampleBuffer.formatDescription else { return }
        let format = AVAudioFormat(cmAudioFormatDescription: description)
        guard format.commonFormat == .pcmFormatFloat32 else { return }

        var needed = 0
        var retainedBlock: CMBlockBuffer?
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: &needed,
            bufferListOut: nil, bufferListSize: 0, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: 0, blockBufferOut: nil)
        guard needed > 0 else { return }
        let storage = UnsafeMutableRawPointer.allocate(byteCount: needed, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { storage.deallocate() }
        let list = storage.bindMemory(to: AudioBufferList.self, capacity: 1)
        let result = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: nil,
            bufferListOut: list, bufferListSize: needed, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: 0, blockBufferOut: &retainedBlock)
        guard result == noErr else { return }
        defer { withExtendedLifetime(retainedBlock) {} }

        let frames = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frames > 0 else { return }
        var mono = [Float](repeating: 0, count: frames)
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        var channelCount = 0
        for buffer in buffers {
            guard let data = buffer.mData else { continue }
            let channels = Int(buffer.mNumberChannels)
            guard channels > 0, Int(buffer.mDataByteSize) >= frames * channels * MemoryLayout<Float>.size else { continue }
            let samples = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: frames * channels))
            let mixed = SpectrumAnalyzer.downmix(interleaved: samples, channels: channels)
            for frame in 0..<frames { mono[frame] += mixed[frame] * Float(channels) }
            channelCount += channels
        }
        guard channelCount > 0 else { return }
        for index in mono.indices { mono[index] /= Float(channelCount) }
        guard let bands = analyzer.consume(mono, sampleRate: format.sampleRate) else { return }
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastPublish >= 1.0 / 30 {
            lastPublish = now
            onSpectrum?(bands)
        }
    }
}

@MainActor
final class AudioCaptureService: ObservableObject {
    enum State { case off, starting, running, failed }
    @Published private(set) var bands = [Float](repeating: 0, count: SpectrumAnalyzer.bandCount)
    @Published private(set) var state: State = .off
    @Published private(set) var errorMessage: String?
    private var stream: SCStream?
    private var output: AudioStreamOutput?
    private let queue = DispatchQueue(label: "dev.caelestia.spectrum", qos: .userInitiated)
    private var generation = UUID()
    private var lastSample = Date.distantPast
    private var silenceTimer: Timer?

    func start() async {
        guard state != .starting, state != .running else { return }
        state = .starting
        errorMessage = nil
        generation = UUID()
        let token = generation
        do {
            // ScreenCaptureKit prompts for Screen & System Audio Recording permission.
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard token == generation else { return }
            guard let display = content.displays.first else {
                throw NSError(domain: "CaelestiaNotch", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display available for audio capture."])
            }
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = 48_000
            configuration.channelCount = 2
            // No screen output is registered or processed. Minimize the required video configuration.
            configuration.width = 2
            configuration.height = 2
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            configuration.showsCursor = false
            let output = AudioStreamOutput()
            output.onSpectrum = { [weak self] values in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    if self.bands != values { self.bands = values }
                    self.lastSample = Date()
                }
            }
            output.onFailure = { [weak self] error in
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    await self.stop()
                    self.state = .failed
                    self.errorMessage = "Audio capture stopped: \(error.localizedDescription)"
                }
            }
            let stream = SCStream(filter: filter, configuration: configuration, delegate: output)
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: queue)
            self.output = output
            self.stream = stream
            try await stream.startCapture()
            guard token == generation else { try? await stream.stopCapture(); return }
            state = .running
            lastSample = Date()
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, Date().timeIntervalSince(self.lastSample) > 0.2 else { return }
                    let decayed = self.bands.map { $0 < 0.005 ? 0 : $0 * 0.6 }
                    if self.bands != decayed { self.bands = decayed }
                }
            }
        } catch {
            guard token == generation else { return }
            if let stream { try? await stream.stopCapture() }
            stream = nil
            output = nil
            state = .failed
            bands = .init(repeating: 0, count: SpectrumAnalyzer.bandCount)
            errorMessage = "Could not capture audio. Allow Caelestia Notch in Screen & System Audio Recording, then retry. \(error.localizedDescription)"
        }
    }

    func stop() async {
        generation = UUID()
        silenceTimer?.invalidate()
        silenceTimer = nil
        let oldStream = stream
        stream = nil
        output = nil
        state = .off
        bands = .init(repeating: 0, count: SpectrumAnalyzer.bandCount)
        if let oldStream { try? await oldStream.stopCapture() }
    }
}
