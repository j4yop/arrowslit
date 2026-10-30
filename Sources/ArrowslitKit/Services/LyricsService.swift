import Foundation
import Observation

/// A song lookup key. Lyrics are fetched once per key and kept only in memory.
public struct LyricsKey: Hashable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: Int?

    public init?(title: String, artist: String, album: String, duration: TimeInterval?) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !artist.isEmpty else { return nil }
        self.title = title
        self.artist = artist
        self.album = album.trimmingCharacters(in: .whitespacesAndNewlines)
        self.duration = duration.map { Int($0.rounded()) }
    }

    public init?(track: NowPlayingTrack?) {
        guard let track else { return nil }
        self.init(title: track.title, artist: track.artist, album: track.album, duration: track.duration)
    }
}

/// Builds LRCLIB requests and accepts only timed lyrics that match the playing song.
public enum LyricsLookup {
    public struct Record: Decodable, Sendable {
        public var duration: Double?
        public var instrumental: Bool?
        public var syncedLyrics: String?
    }

    public static func getURL(for key: LyricsKey) -> URL? {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        var items = [
            URLQueryItem(name: "track_name", value: key.title),
            URLQueryItem(name: "artist_name", value: key.artist),
        ]
        if !key.album.isEmpty { items.append(URLQueryItem(name: "album_name", value: key.album)) }
        if let duration = key.duration { items.append(URLQueryItem(name: "duration", value: String(duration))) }
        components?.queryItems = items
        return components?.url
    }

    public static func searchURL(for key: LyricsKey) -> URL? {
        var components = URLComponents(string: "https://lrclib.net/api/search")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: key.title),
            URLQueryItem(name: "artist_name", value: key.artist),
        ]
        return components?.url
    }

    /// Timed lyrics from a record, if the record is not instrumental and its length is close.
    public static func lyrics(from record: Record, for key: LyricsKey) -> SyncedLyrics? {
        guard record.instrumental != true, let lrc = record.syncedLyrics else { return nil }
        if let wanted = key.duration, let duration = record.duration, abs(duration - Double(wanted)) > 3 {
            return nil
        }
        return SyncedLyrics(lrc: lrc)
    }
}

/// Optional lyrics lookup. Off unless the user turns it on; only the song's title, artist,
/// album and length are sent, and answers live in memory for this launch.
@MainActor
@Observable
public final class LyricsService {
    public private(set) var current: SyncedLyrics?

    @ObservationIgnored private var currentKey: LyricsKey?
    @ObservationIgnored private var cache: [LyricsKey: CachedLyrics] = [:]
    @ObservationIgnored private var cacheOrder: [LyricsKey] = []
    @ObservationIgnored private var lookupTask: Task<Void, Never>?
    @ObservationIgnored private let session: URLSession
    private static let cacheLimit = 100

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func update(for track: NowPlayingTrack?, enabled: Bool) {
        let key = enabled ? LyricsKey(track: track) : nil
        guard key != currentKey else { return }
        currentKey = key
        lookupTask?.cancel()
        lookupTask = nil
        guard let key else {
            current = nil
            return
        }
        if let cached = cache[key] {
            current = cached.lyrics
            return
        }
        current = nil
        lookupTask = Task { [weak self, session] in
            // A short pause so skipping through songs doesn't send a request for each one.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let found = await Self.fetch(key, session: session)
            guard !Task.isCancelled, let self else { return }
            switch found {
            case .found(let lyrics):
                self.remember(lyrics, for: key)
                if self.currentKey == key { self.current = lyrics }
            case .failed:
                // Offline or a server error: leave it uncached so it can be tried again.
                if self.currentKey == key { self.current = nil }
            }
        }
    }

    private enum CachedLyrics {
        case lyrics(SyncedLyrics)
        case none

        var lyrics: SyncedLyrics? {
            if case .lyrics(let lyrics) = self { return lyrics }
            return nil
        }
    }

    private func remember(_ lyrics: SyncedLyrics?, for key: LyricsKey) {
        cache[key] = lyrics.map(CachedLyrics.lyrics) ?? CachedLyrics.none
        cacheOrder.append(key)
        if cacheOrder.count > Self.cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
    }

    private enum FetchResult {
        case found(SyncedLyrics?)
        case failed
    }

    private nonisolated static func fetch(_ key: LyricsKey, session: URLSession) async -> FetchResult {
        if let url = LyricsLookup.getURL(for: key) {
            switch await request(url, as: LyricsLookup.Record.self, session: session) {
            case .found(let record):
                if let lyrics = LyricsLookup.lyrics(from: record, for: key) { return .found(lyrics) }
            case .notFound:
                break
            case .failed:
                return .failed
            }
        }

        guard let url = LyricsLookup.searchURL(for: key) else { return .found(nil) }
        switch await request(url, as: [LyricsLookup.Record].self, session: session) {
        case .found(let records):
            let lyrics = records.lazy.compactMap { LyricsLookup.lyrics(from: $0, for: key) }.first
            return .found(lyrics)
        case .notFound:
            return .found(nil)
        case .failed:
            return .failed
        }
    }

    private enum Response<Value> {
        case found(Value)
        case notFound
        case failed
    }

    private nonisolated static func request<Value: Decodable>(
        _ url: URL,
        as type: Value.Type,
        session: URLSession
    ) async -> Response<Value> {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Arrowslit/0.3 (https://github.com/j4yop/arrowslit)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode else {
            return .failed
        }
        if status == 404 { return .notFound }
        guard status == 200, let value = try? JSONDecoder().decode(Value.self, from: data) else {
            return .failed
        }
        return .found(value)
    }
}
