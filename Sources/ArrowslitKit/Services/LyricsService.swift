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

/// While a song keeps playing and every lyrics provider is unreachable, try again on a
/// widening schedule instead of leaving the player stuck on the placeholder for the whole song.
public enum LyricsRetryPolicy {
    public static let delays: [TimeInterval] = [5, 15, 60, 300]

    public static func delay(afterFailure number: Int) -> TimeInterval {
        delays[min(max(number, 0), delays.count - 1)]
    }
}

/// Builds lyrics requests and accepts only timed lyrics that match the playing song.
public enum LyricsLookup {
    public struct Record: Decodable, Sendable {
        public var duration: Double?
        public var instrumental: Bool?
        public var syncedLyrics: String?
    }

    /// The parts of NetEase Cloud Music's search and lyric responses that we use.
    public struct NetEase: Decodable, Sendable {
        public struct Result: Decodable, Sendable {
            public var songs: [Song]?
        }

        public struct Song: Decodable, Sendable {
            public var id: Int
            public var name: String
            public var duration: Double?
            public var artists: [Artist]
            public var album: Album?

            enum CodingKeys: String, CodingKey {
                case id, name, album
                case duration = "dt"
                case artists = "ar"
            }
        }

        public struct Artist: Decodable, Sendable {
            public var name: String
        }

        public struct Album: Decodable, Sendable {
            public var name: String
        }

        public var result: Result?
    }

    public struct NetEaseLyric: Decodable, Sendable {
        public struct LRC: Decodable, Sendable {
            public var lyric: String
        }

        public var lrc: LRC?
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

    public static func netEaseSearchURL(for key: LyricsKey) -> URL? {
        var components = URLComponents(string: "https://music.163.com/api/cloudsearch/pc")
        components?.queryItems = [
            URLQueryItem(name: "s", value: "\(key.title) \(key.artist)"),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "offset", value: "0"),
        ]
        return components?.url
    }

    public static func netEaseLyricURL(id: Int) -> URL? {
        var components = URLComponents(string: "https://music.163.com/api/song/lyric")
        components?.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "lv", value: "1"),
            URLQueryItem(name: "kv", value: "1"),
            URLQueryItem(name: "tv", value: "-1"),
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

    /// The one search result whose title, artist and length match the playing song.
    public static func match(in search: NetEase, for key: LyricsKey) -> NetEase.Song? {
        let wantedTitle = normalizedTitle(key.title)
        let wantedArtist = normalizedArtist(key.artist)
        guard !wantedTitle.isEmpty, !wantedArtist.isEmpty else { return nil }

        return search.result?.songs?.first { song in
            guard normalizedTitle(song.name) == wantedTitle else { return false }
            guard song.artists.contains(where: { artist in
                let name = normalizedArtist(artist.name)
                return name == wantedArtist || name.contains(wantedArtist) || wantedArtist.contains(name)
            }) else { return false }
            if let wanted = key.duration, let milliseconds = song.duration {
                guard abs(milliseconds / 1000 - Double(wanted)) <= 5 else { return false }
            }
            return true
        }
    }

    public static func lyrics(from lyric: NetEaseLyric, for key: LyricsKey) -> SyncedLyrics? {
        guard let lrc = lyric.lrc?.lyric else { return nil }
        return netEaseLyrics(from: lrc, for: key)
    }

    /// NetEase prepends production credits as timed lines. Drop those so the intro shows music,
    /// not "作词 : ...".
    public static func netEaseLyrics(from lrc: String, for key: LyricsKey) -> SyncedLyrics? {
        let cleaned = lrc
            .split(whereSeparator: \.isNewline)
            .filter { !isCreditLine($0) }
            .joined(separator: "\n")
        return SyncedLyrics(lrc: cleaned)
    }

    /// "After Hours (Live)" and "After Hours - Remastered 2011" both normalize to "after hours".
    public static func normalizedTitle(_ text: String) -> String {
        var value = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        value = value.replacingOccurrences(of: "’", with: "'")
        value = value.replacingOccurrences(
            of: #"\s*[\(\[].*?[\)\]]"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(
            of: #"\s+-\s+(remaster(ed)?|live|acoustic|mono|stereo|deluxe|radio edit|single version)\b.*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        return value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func normalizedArtist(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isCreditLine(_ raw: Substring) -> Bool {
        var rest = raw
        while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
            rest = rest[rest.index(after: close)...]
        }
        let text = rest.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return false }

        let lower = text.lowercased()
        let labels = [
            "作词", "作曲", "编曲", "制作人", "监制", "混音", "母带", "和声", "录音",
            "出品", "发行", "策划", "统筹", "吉他", "贝斯", "鼓", "键盘", "弦乐",
            "人声", "封面", "词", "曲",
            "producer", "written by", "composed by", "lyrics by", "music by",
            "arranged by", "mixed by", "mastered by", "recorded by", "engineer",
            "vocals", "guitar", "bass", "drums", "keyboard", "strings", "label",
            "publisher",
        ]
        return labels.contains { label in
            guard lower.hasPrefix(label) else { return false }
            let after = String(lower.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
            return after.hasPrefix(":") || after.hasPrefix("：")
        }
    }
}

/// Optional lyrics lookup. Off unless the user turns it on; only the song's title, artist,
/// album and length are sent, and answers live in memory for this launch.
@MainActor
@Observable
public final class LyricsService {
    public enum Status: Equatable, Sendable {
        case idle
        case searching
        case available
        case unavailable
    }

    public private(set) var current: SyncedLyrics?
    public private(set) var status: Status = .idle

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
            status = .idle
            return
        }

        if let cached = cache[key] {
            current = cached.lyrics
            status = cached.lyrics == nil ? .unavailable : .available
            return
        }

        current = nil
        status = .searching
        lookupTask = Task { [weak self, session] in
            // A short pause so skipping through songs doesn't send a request for each one.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            var failures = 0
            while !Task.isCancelled {
                let found = await Self.fetch(key, session: session)
                guard !Task.isCancelled, let self else { return }

                switch found {
                case .found(let lyrics):
                    self.remember(lyrics, for: key)
                    guard self.currentKey == key else { return }
                    self.current = lyrics
                    self.status = lyrics == nil ? .unavailable : .available
                    return
                case .failed:
                    // The same song is still playing: keep trying instead of staying on "♪".
                    guard self.currentKey == key else { return }
                    self.current = nil
                    self.status = .unavailable
                    let delay = LyricsRetryPolicy.delay(afterFailure: failures)
                    failures += 1
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    if self.currentKey == key { self.status = .searching }
                }
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
        var sawFailure = false

        if let url = LyricsLookup.getURL(for: key) {
            switch await request(url, as: LyricsLookup.Record.self, session: session) {
            case .found(let record):
                if let lyrics = LyricsLookup.lyrics(from: record, for: key) { return .found(lyrics) }
            case .notFound:
                break
            case .failed:
                sawFailure = true
            }
        }

        if let url = LyricsLookup.searchURL(for: key) {
            switch await request(url, as: [LyricsLookup.Record].self, session: session) {
            case .found(let records):
                if let lyrics = records.lazy.compactMap({ LyricsLookup.lyrics(from: $0, for: key) }).first {
                    return .found(lyrics)
                }
            case .notFound:
                break
            case .failed:
                sawFailure = true
            }
        }

        // LRCLIB is the primary source. This is the timed fallback for outages and gaps.
        if let url = LyricsLookup.netEaseSearchURL(for: key) {
            switch await request(url, as: LyricsLookup.NetEase.self, session: session) {
            case .found(let search):
                if let song = LyricsLookup.match(in: search, for: key),
                   let lyricURL = LyricsLookup.netEaseLyricURL(id: song.id) {
                    switch await request(lyricURL, as: LyricsLookup.NetEaseLyric.self, session: session) {
                    case .found(let lyric):
                        if let lyrics = LyricsLookup.lyrics(from: lyric, for: key) { return .found(lyrics) }
                    case .notFound:
                        break
                    case .failed:
                        sawFailure = true
                    }
                }
            case .notFound:
                break
            case .failed:
                sawFailure = true
            }
        }

        // A provider being down is not the same as "this song has no lyrics": retry the former.
        return sawFailure ? .failed : .found(nil)
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
        request.setValue(
            "Arrowslit/0.4.6 (https://github.com/j4yop/arrowslit)",
            forHTTPHeaderField: "User-Agent"
        )
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
