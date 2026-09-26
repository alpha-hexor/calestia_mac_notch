import Combine
import Foundation

@MainActor
final class BongoCatController: ObservableObject {
    @Published private(set) var beatCount: UInt = 0
    @Published private(set) var tapStrength: Double = 0
    private var rhythm = BongoRhythm()
    private var subscription: AnyCancellable?
    private var settleTask: Task<Void, Never>?

    func connect(audio: AudioCaptureService, spotify: SpotifyService) {
        subscription = audio.$bands
            .combineLatest(spotify.$isPlaying.removeDuplicates(), audio.$state.removeDuplicates())
            .sink { [weak self] bands, playing, captureState in
                self?.update(bands: bands, playing: playing, capturing: captureState == .running)
            }
    }

    private func update(bands: [Float], playing: Bool, capturing: Bool) {
        let strength = rhythm.update(bands: bands, at: ProcessInfo.processInfo.systemUptime,
                                     isPlaying: playing, isCapturing: capturing)
        guard playing, capturing else {
            settleTask?.cancel()
            settleTask = nil
            if tapStrength != 0 { tapStrength = 0 }
            return
        }
        guard let strength else { return }
        beatCount = rhythm.beatCount
        tapStrength = strength
        settleTask?.cancel()
        settleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            self?.tapStrength = 0
        }
    }
}
