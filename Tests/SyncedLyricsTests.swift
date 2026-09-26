import XCTest
@testable import CaelestiaCore

final class SyncedLyricsTests: XCTestCase {
    func testTimestampsUnicodeRepeatedLinesAndBlankGaps() {
        let lyrics = SyncedLyrics(lrc: """
            [ar:Test artist]
            [00:01.5]First test line
            [00:03.05]こんにちは · नमस्ते
            [00:04.125][00:09.125]Repeated test line
            [00:06.00]
            [00:99]Invalid seconds
            not a timestamp
            """)
        XCTAssertEqual(lyrics.lines.map(\.time), [1.5, 3.05, 4.125, 6, 9.125])
        XCTAssertEqual(lyrics.line(at: 3.5)?.text, "こんにちは · नमस्ते")
        XCTAssertEqual(lyrics.line(at: 6.5)?.text, "", "Blank timestamps clear the previous line during instrumental gaps")
        XCTAssertEqual(lyrics.line(at: 9.125)?.text, "Repeated test line")
        XCTAssertTrue(lyrics.hasText)
    }

    func testSelectionBeforeFirstLineAtBoundariesAndAfterBackwardSeek() {
        let lyrics = SyncedLyrics(lrc: "[00:10]Test one\n[00:20]Test two\n[00:30]Test three")
        XCTAssertNil(lyrics.line(at: 0), "Do not show the first lyric throughout the intro")
        XCTAssertEqual(lyrics.line(at: 19.99)?.text, "Test one")
        XCTAssertEqual(lyrics.line(at: 20)?.text, "Test two")
        XCTAssertEqual(lyrics.line(at: 90)?.text, "Test three")
        XCTAssertEqual(lyrics.line(at: 11)?.text, "Test one")
        XCTAssertNil(lyrics.line(at: .nan))
    }

    func testOffsetsOutOfOrderLinesAndDuplicateTimestamps() {
        let lyrics = SyncedLyrics(lrc: "[offset:+500]\n[00:04]Later\n[00:01]Old\n[00:01]Replacement\n[00:00.1]Intro")
        XCTAssertEqual(lyrics.lines.map(\.time), [0, 0.5, 3.5])
        XCTAssertEqual(lyrics.line(at: 0.5)?.text, "Replacement")
        let delayed = SyncedLyrics(lrc: "[offset:-250]\n[00:01]Delayed test line")
        XCTAssertEqual(delayed.lines.first?.time, 1.25)
    }

    func testPlainLyricsAndEmptyTimestampLinesAreNotTreatedAsSyncedText() {
        XCTAssertFalse(SyncedLyrics(lrc: "A plain test line\nAnother test line").hasText)
        XCTAssertFalse(SyncedLyrics(lrc: "[00:01]\n[00:02]").hasText)
    }

    func testPlaybackInterpolationPauseSeekAndStalePoll() {
        var clock = PlaybackClock(trackID: "test", position: 10, duration: 100, isPlaying: true, sampledAt: 50)
        XCTAssertEqual(clock.position(at: 50.4), 10.4, accuracy: 0.001)
        XCTAssertEqual(clock.position(at: 60), 12, "Freeze extrapolation when Spotify stops reporting")
        clock = PlaybackClock(trackID: "test", position: 10.4, duration: 100, isPlaying: false, sampledAt: 50.4)
        XCTAssertEqual(clock.position(at: 60), 10.4, accuracy: 0.001)
        clock = PlaybackClock(trackID: "test", position: 70, duration: 100, isPlaying: true, sampledAt: 60)
        XCTAssertEqual(clock.position(at: 60.2), 70.2, accuracy: 0.001)
        clock = PlaybackClock(trackID: "test", position: 5, duration: 100, isPlaying: true, sampledAt: 61)
        XCTAssertEqual(clock.position(at: 61.1), 5.1, accuracy: 0.001)
        clock.position = 99.9
        XCTAssertEqual(clock.position(at: 62), 100)
        clock.position = .nan
        XCTAssertEqual(clock.position(at: 62), 0)
    }
}
