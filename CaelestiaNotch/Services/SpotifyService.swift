import AppKit
import Combine

struct SpotifyTrack: Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let artworkURL: String
}

private struct ScriptFailure: Error {
    let code: Int
    let message: String
}

/// AppleScript is serialized away from the UI thread, including slow permission prompts.
private final class SpotifyScriptRunner: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.caelestia.spotify", qos: .userInitiated)

    func run(_ body: String) async throws -> NSAppleEventDescriptor {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let source = "with timeout of 5 seconds\ntell application id \"com.spotify.client\"\n\(body)\nend tell\nend timeout"
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(throwing: ScriptFailure(code: -1, message: "Could not create Spotify command."))
                    return
                }
                var error: NSDictionary?
                let result = script.executeAndReturnError(&error)
                if let error {
                    continuation.resume(throwing: ScriptFailure(
                        code: error[NSAppleScript.errorNumber] as? Int ?? -1,
                        message: error[NSAppleScript.errorMessage] as? String ?? "Spotify did not respond."))
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

@MainActor
final class SpotifyService: ObservableObject {
    @Published private(set) var track: SpotifyTrack?
    @Published private(set) var artwork: NSImage?
    @Published private(set) var isPlaying = false
    @Published private(set) var isRunning = false
    @Published private(set) var position: Double = 0
    @Published private(set) var playbackClock = PlaybackClock()
    @Published private(set) var permissionDenied = false
    @Published private(set) var errorMessage: String?
    private var timer: Timer?
    private var refreshing = false
    private var playbackRevision: UInt = 0
    private var artworkTask: Task<Void, Never>?
    private let runner = SpotifyScriptRunner()

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func retry() {
        permissionDenied = false
        errorMessage = nil
        Task { await refresh() }
    }

    func openSpotify() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") else {
            errorMessage = "Install the Spotify desktop app to get started."
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }

    func togglePlayback() { command("playpause") }
    func next() { command("next track") }
    func previous() { command("previous track") }
    func seek(to seconds: Double) {
        guard seconds.isFinite, let track else { return }
        let target = min(max(seconds, 0), track.duration)
        playbackRevision &+= 1
        position = target
        recordPlayback()
        command("set player position to \(target)")
    }

    private func command(_ body: String) {
        guard isRunning, !permissionDenied else { return }
        Task {
            do {
                _ = try await runner.run(body)
                await refresh()
            } catch { handle(error) }
        }
    }

    private func refresh() async {
        guard !refreshing else { return }
        isRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        guard isRunning else {
            track = nil
            artwork = nil
            isPlaying = false
            position = 0
            errorMessage = nil
            artworkTask?.cancel()
            recordPlayback()
            return
        }
        guard !permissionDenied else { return }
        refreshing = true
        let revision = playbackRevision
        defer { refreshing = false }
        do {
            let result = try await runner.run("""
                set playbackState to player state as text
                if playbackState is "stopped" then return {"empty", playbackState}
                set t to current track
                return {"track", playbackState, id of t, name of t, artist of t, album of t, duration of t, artwork url of t, player position}
                """)
            guard revision == playbackRevision else { return }
            errorMessage = nil
            isPlaying = result.atIndex(2)?.stringValue == "playing"
            guard result.atIndex(1)?.stringValue == "track", result.numberOfItems >= 9 else {
                track = nil
                artwork = nil
                position = 0
                artworkTask?.cancel()
                recordPlayback()
                return
            }
            // Spotify returns duration in milliseconds despite the wording in its dictionary.
            let newTrack = SpotifyTrack(
                id: result.atIndex(3)?.stringValue ?? "",
                title: result.atIndex(4)?.stringValue ?? "Unknown track",
                artist: result.atIndex(5)?.stringValue ?? "",
                album: result.atIndex(6)?.stringValue ?? "",
                duration: max(0, (result.atIndex(7)?.doubleValue ?? 0) / 1000),
                artworkURL: result.atIndex(8)?.stringValue ?? "")
            if newTrack.artworkURL != track?.artworkURL { loadArtwork(newTrack.artworkURL) }
            track = newTrack
            position = min(newTrack.duration, max(0, result.atIndex(9)?.doubleValue ?? 0))
            recordPlayback()
        } catch { handle(error) }
    }

    private func handle(_ error: Error) {
        if let failure = error as? ScriptFailure, failure.code == -1743 {
            permissionDenied = true
            isPlaying = false
            errorMessage = "Allow Spotify access in System Settings → Privacy & Security → Automation, then retry."
        } else {
            errorMessage = "Spotify is not responding. Open Spotify and try again."
        }
        recordPlayback()
    }

    private func recordPlayback() {
        playbackClock = PlaybackClock(trackID: track?.id, position: position, duration: track?.duration ?? 0,
                                      isPlaying: isPlaying && errorMessage == nil,
                                      sampledAt: ProcessInfo.processInfo.systemUptime)
    }

    private func loadArtwork(_ address: String) {
        artworkTask?.cancel()
        artwork = nil
        guard let url = URL(string: address), url.scheme == "https" else { return }
        artworkTask = Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, (response as? HTTPURLResponse)?.statusCode == 200 else { return }
                self?.artwork = NSImage(data: data)
            } catch { /* Placeholder artwork remains available offline. */ }
        }
    }
}
