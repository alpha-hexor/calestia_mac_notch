import SwiftUI

struct LyricLineView: View {
    @ObservedObject var spotify: SpotifyService
    @ObservedObject var lyrics: LyricsService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !spotify.isPlaying || !lyrics.hasSyncedLyrics)) { _ in
            let text = displayedLine
            Group {
                if lyrics.state == .failed {
                    Button("Couldn't load lyrics · Retry", action: lyrics.retry).buttonStyle(.plain)
                } else {
                    Text(text)
                        .contentTransition(.opacity)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: text)
                }
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(lyrics.hasSyncedLyrics ? Palette.accent : Palette.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity)
            .help(text + "\nLyrics provided by LRCLIB · synced to Spotify")
            .accessibilityLabel("Lyrics: \(text)")
        }
        .frame(height: 18)
        .clipped()
    }

    private var displayedLine: String {
        switch lyrics.state {
        case .idle: return "Lyrics appear here"
        case .loading: return "Finding lyrics…"
        case .failed: return "Couldn't load lyrics · Retry"
        case .available(.instrumental): return "♪ Instrumental"
        case .available(.unavailable): return "Synced lyrics unavailable"
        case .available(.synced(let timeline)):
            guard lyrics.trackID == spotify.playbackClock.trackID else { return "Finding lyrics…" }
            let position = spotify.playbackClock.position(at: ProcessInfo.processInfo.systemUptime)
            let text = timeline.line(at: position)?.text ?? ""
            return text.isEmpty ? "♪" : text
        }
    }
}
