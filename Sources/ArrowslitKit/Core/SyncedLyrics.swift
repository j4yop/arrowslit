import Foundation

/// Lyrics timed to a song, parsed from an LRC file ("[01:23.45] words").
public struct SyncedLyrics: Equatable, Sendable {
    public struct Line: Equatable, Sendable {
        public var time: TimeInterval
        public var text: String

        public init(time: TimeInterval, text: String) {
            self.time = time
            self.text = text
        }
    }

    public let lines: [Line]

    /// Nil for plain lyrics or files that contain only tags.
    public init?(lrc: String) {
        var parsed: [Line] = []
        for raw in lrc.split(whereSeparator: \.isNewline) {
            var rest = Substring(raw)
            var times: [TimeInterval] = []
            while rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let stamp = rest[rest.index(after: rest.startIndex)..<close]
                guard let time = Self.seconds(stamp) else { break }
                times.append(time)
                rest = rest[rest.index(after: close)...]
            }
            let text = rest.trimmingCharacters(in: .whitespaces)
            parsed += times.map { Line(time: $0, text: text) }
        }
        guard parsed.contains(where: { !$0.text.isEmpty }) else { return nil }
        lines = parsed.sorted { $0.time < $1.time }
    }

    /// The last line at or before `elapsed`, or nil before the first line.
    public func index(at elapsed: TimeInterval) -> Int? {
        var low = 0
        var high = lines.count - 1
        var found: Int?
        while low <= high {
            let middle = (low + high) / 2
            if lines[middle].time <= elapsed {
                found = middle
                low = middle + 1
            } else {
                high = middle - 1
            }
        }
        return found
    }

    private static func seconds(_ stamp: Substring) -> TimeInterval? {
        let parts = stamp.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let minutes = Double(parts[0]) else { return nil }
        let seconds = parts[1].replacingOccurrences(of: ":", with: ".")
        guard let value = Double(seconds), value < 60 else { return nil }
        return minutes * 60 + value
    }
}
