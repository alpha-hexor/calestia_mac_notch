import XCTest
@testable import CaelestiaCore

private actor FixtureLyricsTransport: LyricsTransport {
    private var responses: [(Int, Data)]
    private(set) var requests: [URLRequest] = []

    init(_ responses: [(Int, Data)]) { self.responses = responses }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        let response = responses.removeFirst()
        return (response.1, HTTPURLResponse(url: request.url!, statusCode: response.0, httpVersion: nil, headerFields: nil)!)
    }
}

final class LRCLIBClientTests: XCTestCase {
    private let query = LyricsQuery(title: "Test song", artist: "Test artist", album: "Test album", duration: 200)

    private func record(title: String = "Test song", artist: String = "Test artist", album: String = "Test album",
                        duration: Double = 200, instrumental: Bool = false, synced: String? = "[00:01]Synthetic line") -> [String: Any] {
        ["trackName": title, "artistName": artist, "albumName": album, "duration": duration,
         "instrumental": instrumental, "syncedLyrics": synced as Any? ?? NSNull()]
    }

    private func data(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    func testExactMatchIsCachedWithoutFetchingEveryPlaybackTick() async throws {
        let transport = FixtureLyricsTransport([(200, try data(record()))])
        let client = LRCLIBClient(transport: transport)
        let first = try await client.lyrics(for: query)
        let second = try await client.lyrics(for: query)
        XCTAssertEqual(first, .synced(SyncedLyrics(lrc: "[00:01]Synthetic line")))
        XCTAssertEqual(second, first)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.path, "/api/get")
    }

    func testSearchFallbackRejectsWrongArtistAndWrongRecordingDuration() async throws {
        let candidates = [
            record(artist: "Unrelated artist", synced: "[00:01]Wrong artist"),
            record(duration: 260, synced: "[00:01]Wrong version"),
            record(album: "Compilation", duration: 200.5, synced: "[00:02]Correct test line"),
        ]
        let transport = FixtureLyricsTransport([(404, Data()), (200, try data(candidates))])
        let result = try await LRCLIBClient(transport: transport).lyrics(for: query)
        XCTAssertEqual(result, .synced(SyncedLyrics(lrc: "[00:02]Correct test line")))
        let paths = await transport.requests.map { $0.url!.path }
        XCTAssertEqual(paths, ["/api/get", "/api/search"])
    }

    func testOnlyMismatchedSearchResultsReturnUnavailable() async throws {
        let transport = FixtureLyricsTransport([(404, Data()), (200, try data([record(title: "Another song")]))])
        let result = try await LRCLIBClient(transport: transport).lyrics(for: query)
        XCTAssertEqual(result, .unavailable)
    }

    func testInstrumentalStopsLookupAndPlainLyricsDoNotGetInventedTiming() async throws {
        let instrumental = FixtureLyricsTransport([(200, try data(record(instrumental: true, synced: nil)))])
        let instrumentalResult = try await LRCLIBClient(transport: instrumental).lyrics(for: query)
        XCTAssertEqual(instrumentalResult, .instrumental)
        let plain = FixtureLyricsTransport([(200, try data(record(synced: nil))), (200, try data([record(synced: nil)]))])
        let plainResult = try await LRCLIBClient(transport: plain).lyrics(for: query)
        XCTAssertEqual(plainResult, .unavailable)
    }

    func testReservedCharactersRemainInsideQueryValues() async throws {
        let title = "Test & title? #1 + café"
        let artist = "Artist A & Artist B"
        let transport = FixtureLyricsTransport([(200, try data(record(title: title, artist: artist)))])
        let query = LyricsQuery(title: title, artist: artist, album: "Album #2", duration: 200)
        _ = try await LRCLIBClient(transport: transport).lyrics(for: query)
        let request = await transport.requests[0]
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.first { $0.name == "track_name" }?.value, title)
        XCTAssertEqual(items.first { $0.name == "artist_name" }?.value, artist)
        XCTAssertEqual(items.first { $0.name == "album_name" }?.value, "Album #2")
        XCTAssertTrue(request.url!.absoluteString.contains("%2B"), "A literal plus must not become a space on the server")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "User-Agent"))
    }

    func testHTTPFailureIsRetryableAndDoesNotTriggerExtraSearchRequests() async throws {
        let transport = FixtureLyricsTransport([(429, Data()), (200, try data(record()))])
        let client = LRCLIBClient(transport: transport)
        do {
            _ = try await client.lyrics(for: query)
            XCTFail("A rate-limit response should not be treated as missing lyrics")
        } catch LyricsLookupError.http(let status) {
            XCTAssertEqual(status, 429)
        }
        let retried = try await client.lyrics(for: query)
        XCTAssertEqual(retried, .synced(SyncedLyrics(lrc: "[00:01]Synthetic line")))
        let count = await transport.requests.count
        XCTAssertEqual(count, 2)
    }

    func testDifferentAlbumAndDurationUseDifferentCacheEntries() async throws {
        let transport = FixtureLyricsTransport([
            (200, try data(record())),
            (200, try data(record(album: "Live", duration: 250, synced: "[00:10]Live test line"))),
        ])
        let client = LRCLIBClient(transport: transport)
        _ = try await client.lyrics(for: query)
        let live = try await client.lyrics(for: LyricsQuery(title: query.title, artist: query.artist, album: "Live", duration: 250))
        XCTAssertEqual(live, .synced(SyncedLyrics(lrc: "[00:10]Live test line")))
        let count = await transport.requests.count
        XCTAssertEqual(count, 2)
    }
}
