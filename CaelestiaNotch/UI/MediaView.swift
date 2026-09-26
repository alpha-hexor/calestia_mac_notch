import SwiftUI

struct MediaView: View {
    @ObservedObject var spotify: SpotifyService
    @ObservedObject var audio: AudioCaptureService
    let bongo: BongoCatController

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 18) {
                RadialVisualizer(image: spotify.artwork, bands: audio.bands, isPlaying: spotify.isPlaying)
                    .frame(width: 210, height: 210)
                VStack(spacing: 10) {
                    metadata
                    PlaybackControls(spotify: spotify)
                    if let track = spotify.track {
                        SeekBar(position: spotify.position, duration: track.duration, onSeek: spotify.seek)
                    }
                    Button(action: spotify.openSpotify) {
                        HStack(spacing: 5) {
                            Image(systemName: "waveform.circle.fill").foregroundStyle(Color(red: 0.15, green: 0.66, blue: 0.38))
                            Text("Spotify").font(.system(size: 10, weight: .medium))
                            Image(systemName: "arrow.up.right").font(.system(size: 8))
                        }
                    }.buttonStyle(SoftButtonStyle())
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 8) {
                    BongoCatView(motion: bongo)
                        .frame(width: 158, height: 130)
                    Text(spotify.isPlaying ? "a little company, a little music" : "waiting for a little music")
                        .font(.system(size: 9)).foregroundStyle(Palette.muted)
                }.frame(width: 165)
            }
            footer.frame(height: 24)
        }
    }

    private var metadata: some View {
        VStack(spacing: 6) {
            Text(spotify.track?.title ?? (spotify.isRunning ? "Your next favorite song" : "Make yourself at home"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.accent).lineLimit(2).multilineTextAlignment(.center)
            Text(spotify.track?.artist ?? "Open Spotify and play something.")
                .font(.system(size: 12)).lineLimit(1).foregroundStyle(Palette.muted)
            if let album = spotify.track?.album, !album.isEmpty {
                Text(album).font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.8)).lineLimit(1)
            }
        }.frame(height: 65)
    }

    @ViewBuilder private var footer: some View {
        if spotify.permissionDenied {
            HStack(spacing: 8) {
                Text("Allow Spotify access to connect.")
                Button("Settings", action: PermissionSettings.openAutomation)
                Button("Retry", action: spotify.retry)
            }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(Palette.accent)
        } else if let error = spotify.errorMessage {
            HStack {
                Text(error).lineLimit(1).help(error)
                Button("Retry", action: spotify.retry).buttonStyle(.plain)
            }.font(.system(size: 10)).foregroundStyle(Palette.accent)
        } else {
            HStack(spacing: 7) {
                Circle().fill(audio.state == .running ? Palette.olive : Palette.muted.opacity(0.45)).frame(width: 5, height: 5)
                Text(audioLabel).font(.system(size: 9)).foregroundStyle(Palette.muted)
                if audio.state == .off || audio.state == .failed {
                    Button(audio.state == .failed ? "Retry" : "Enable visualizer") { Task { await audio.start() } }
                        .font(.system(size: 10, weight: .medium)).buttonStyle(.plain).foregroundStyle(Palette.accent)
                    if audio.state == .failed {
                        Button("Settings", action: PermissionSettings.openCapture)
                            .font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(Palette.accent)
                        Button("Details") {
                            PermissionSettings.showCaptureError(audio.errorMessage ?? "System audio is unavailable.")
                        }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(Palette.accent)
                    }
                }
            }.help(audio.errorMessage ?? "Uses system audio, never your microphone. No audio is saved.")
        }
    }

    private var audioLabel: String {
        switch audio.state {
        case .off: "Real audio-reactive bars · audio capture permission required"
        case .starting: "Connecting to system audio…"
        case .running: "LIVE SPECTRUM · SYSTEM AUDIO"
        case .failed: "Audio capture unavailable · check recording permission"
        }
    }
}

struct PlaybackControls: View {
    @ObservedObject var spotify: SpotifyService
    var compact = false
    var body: some View {
        HStack(spacing: compact ? 15 : 22) {
            Button(action: spotify.previous) { Image(systemName: "backward.end.fill") }
                .accessibilityLabel("Previous track")
            Button(action: spotify.togglePlayback) {
                Image(systemName: spotify.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: compact ? 12 : 17, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                    .frame(width: compact ? 30 : 40, height: compact ? 30 : 40)
                    .background(Palette.accent, in: Circle())
            }.accessibilityLabel(spotify.isPlaying ? "Pause" : "Play")
            Button(action: spotify.next) { Image(systemName: "forward.end.fill") }
                .accessibilityLabel("Next track")
        }
        .font(.system(size: compact ? 11 : 14))
        .buttonStyle(.plain)
        .disabled(!spotify.isRunning || spotify.permissionDenied || spotify.track == nil)
        .opacity(spotify.track == nil ? 0.45 : 1)
    }
}

private struct SeekBar: View {
    let position: Double
    let duration: Double
    let onSeek: (Double) -> Void
    @State private var dragging = false
    @State private var draft = 0.0

    var body: some View {
        VStack(spacing: 0) {
            Slider(value: Binding(get: { dragging ? draft : position }, set: { draft = $0 }),
                   in: 0...max(duration, 1), onEditingChanged: { editing in
                if editing { draft = position; dragging = true }
                else { dragging = false; onSeek(draft) }
            })
            .tint(Palette.accent).controlSize(.mini)
            .disabled(duration <= 0)
            .accessibilityLabel("Playback position")
            HStack {
                Text(playbackTime(dragging ? draft : position))
                Spacer()
                Text(playbackTime(duration))
            }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
        }
    }
}
