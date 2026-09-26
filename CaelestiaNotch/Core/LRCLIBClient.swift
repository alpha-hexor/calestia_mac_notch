import Foundation

struct LyricsQuery: Hashable, Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
}

enum LyricsResult: Equatable, Sendable {
    case synced(SyncedLyrics)
    case instrumental
    case unavailable
}

protocol LyricsTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionLyricsTransport: LyricsTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }
}

enum LyricsLookupError: Error { case http(Int) }

/// Public LRCLIB lookup, independent of Spotify automation and audio capture.
actor LRCLIBClient {
    private struct Record: Decodable {
        let trackName: String
        let artistName: String
        let albumName: String
        let duration: Double
        let instrumental: Bool
        let syncedLyrics: String?

        var lyrics: LyricsResult {
            if instrumental { return .instrumental }
            let parsed = SyncedLyrics(lrc: syncedLyrics ?? "")
            return parsed.hasText ? .synced(parsed) : .unavailable
        }
    }

    private let transport: any LyricsTransport
    private var cache: [LyricsQuery: LyricsResult] = [:]
    private var insertionOrder: [LyricsQuery] = []

    init(transport: any LyricsTransport = URLSessionLyricsTransport()) {
        self.transport = transport
    }

    func lyrics(for query: LyricsQuery) async throws -> LyricsResult {
        try Task.checkCancellation()
        guard !query.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !query.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              query.duration.isFinite, query.duration > 0 else { return .unavailable }
        if let cached = cache[query] { return cached }

        let exact = try await request(path: "get", query: query)
        if exact.1.statusCode == 200 {
            let record = try JSONDecoder().decode(Record.self, from: exact.0)
            let result = record.lyrics
            if matches(record, query: query), result != .unavailable {
                return remember(result, for: query)
            }
        } else if exact.1.statusCode != 404 {
            throw LyricsLookupError.http(exact.1.statusCode)
        }

        try Task.checkCancellation()
        let search = try await request(path: "search", query: query)
        guard search.1.statusCode == 200 else { throw LyricsLookupError.http(search.1.statusCode) }
        let candidates = try JSONDecoder().decode([Record].self, from: search.0)
            .filter { matches($0, query: query) }
            .sorted { score($0, query: query) > score($1, query: query) }
        let result = candidates.lazy.map(\.lyrics).first(where: { $0 != .unavailable }) ?? .unavailable
        try Task.checkCancellation()
        return remember(result, for: query)
    }

    private func request(path: String, query: LyricsQuery) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(string: "https://lrclib.net/api/\(path)")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: query.title),
            URLQueryItem(name: "artist_name", value: query.artist),
        ]
        if path == "get" {
            components.queryItems?.append(URLQueryItem(name: "album_name", value: query.album))
            components.queryItems?.append(URLQueryItem(name: "duration", value: String(Int(query.duration.rounded()))))
        }
        // Servers commonly decode query strings as form data, where a bare '+' means a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10
        request.setValue("CaelestiaNotch/0.1 (macOS; synchronized lyrics)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let response = try await transport.data(for: request)
        try Task.checkCancellation()
        return response
    }

    private func matches(_ record: Record, query: LyricsQuery) -> Bool {
        guard normalized(record.trackName) == normalized(query.title),
              record.duration.isFinite, abs(record.duration - query.duration) <= 3 else { return false }
        let artist = normalized(record.artistName)
        let acceptedArtists = [query.artist] + query.artist.components(separatedBy: ",")
        return !artist.isEmpty && acceptedArtists.contains { normalized($0) == artist }
    }

    private func score(_ record: Record, query: LyricsQuery) -> Double {
        let hasSynced = record.syncedLyrics?.isEmpty == false ? 20.0 : 0
        let albumMatch = normalized(record.albumName) == normalized(query.album) ? 5.0 : 0
        return hasSynced + albumMatch - abs(record.duration - query.duration)
    }

    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func remember(_ result: LyricsResult, for query: LyricsQuery) -> LyricsResult {
        if cache[query] == nil {
            if insertionOrder.count >= 100 { cache.removeValue(forKey: insertionOrder.removeFirst()) }
            insertionOrder.append(query)
        }
        cache[query] = result
        return result
    }
}
