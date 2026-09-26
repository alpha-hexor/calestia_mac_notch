import Combine
import Foundation

@MainActor
final class LyricsService: ObservableObject {
    enum State: Equatable {
        case idle, loading, available(LyricsResult), failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var trackID: String?
    private let client = LRCLIBClient()
    private var subscription: AnyCancellable?
    private var fetchTask: Task<Void, Never>?
    private var requestID = UUID()
    private var currentTrack: SpotifyTrack?

    var hasSyncedLyrics: Bool {
        if case .available(.synced) = state { return true }
        return false
    }

    func connect(spotify: SpotifyService) {
        subscription = spotify.$track.removeDuplicates().sink { [weak self] track in
            self?.load(track)
        }
    }

    func retry() { load(currentTrack) }

    private func load(_ track: SpotifyTrack?) {
        fetchTask?.cancel()
        fetchTask = nil
        requestID = UUID()
        let token = requestID
        currentTrack = track
        trackID = track?.id
        guard let track else { state = .idle; return }
        state = .loading
        let query = LyricsQuery(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
        fetchTask = Task { [weak self, client] in
            do {
                let lyrics = try await client.lyrics(for: query)
                guard !Task.isCancelled, let self, self.requestID == token else { return }
                self.state = .available(lyrics)
            } catch {
                guard !Task.isCancelled, let self, self.requestID == token else { return }
                self.state = .failed
            }
        }
    }
}
