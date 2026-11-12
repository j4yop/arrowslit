import Foundation

/// Recently copied items, newest first, with pinned clips kept at the top. Unpinned copies live
/// in memory only; pinned ones are saved. Rich entries keep their image on disk and only store
/// the file name in the history model.
public struct ClipboardHistory: Equatable, Sendable {
    public struct Entry: Identifiable, Equatable, Sendable, Codable {
        public enum Kind: String, Codable, Sendable, CaseIterable {
            case text
            case image
            case file
            case url
            case clip

            public var title: String {
                switch self {
                case .text: "Text"
                case .image: "Image"
                case .file: "File"
                case .url: "Link"
                case .clip: "Clip"
                }
            }

            public var symbol: String {
                switch self {
                case .text: "doc.text"
                case .image: "photo"
                case .file: "doc"
                case .url: "link"
                case .clip: "paperclip"
                }
            }
        }

        public let id: UUID
        public var kind: Kind
        public var text: String
        public let appName: String?
        public var copiedAt: Date
        public var isPinned: Bool
        public let imageFilename: String?
        public let imageWidth: Int?
        public let imageHeight: Int?
        public let imageHash: String?
        public let filePath: String?

        public init(
            id: UUID = UUID(),
            kind: Kind = .text,
            text: String,
            appName: String?,
            copiedAt: Date = Date(),
            isPinned: Bool = false,
            imageFilename: String? = nil,
            imageWidth: Int? = nil,
            imageHeight: Int? = nil,
            imageHash: String? = nil,
            filePath: String? = nil
        ) {
            self.id = id
            self.kind = kind
            self.text = text
            self.appName = appName
            self.copiedAt = copiedAt
            self.isPinned = isPinned
            self.imageFilename = imageFilename
            self.imageWidth = imageWidth
            self.imageHeight = imageHeight
            self.imageHash = imageHash
            self.filePath = filePath
        }

        private enum CodingKeys: String, CodingKey {
            case id, kind, text, appName, copiedAt, isPinned
            case imageFilename, imageWidth, imageHeight, imageHash, filePath
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .text
            text = try container.decode(String.self, forKey: .text)
            appName = try container.decodeIfPresent(String.self, forKey: .appName)
            copiedAt = try container.decode(Date.self, forKey: .copiedAt)
            isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
            imageFilename = try container.decodeIfPresent(String.self, forKey: .imageFilename)
            imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
            imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
            imageHash = try container.decodeIfPresent(String.self, forKey: .imageHash)
            filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        }

        public var isEmpty: Bool {
            switch kind {
            case .text, .url:
                return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .image:
                return imageFilename == nil
            case .file:
                return filePath == nil
            case .clip:
                return false
            }
        }

        public var previewText: String {
            switch kind {
            case .text, .url:
                return ClipboardHistory.preview(text, limit: 220)
            case .image:
                if let imageWidth, let imageHeight { return "Image · \(imageWidth) × \(imageHeight)" }
                return "Image"
            case .file:
                return text.isEmpty ? (filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File") : text
            case .clip:
                return "Preview unavailable"
            }
        }

        public var characterCount: Int {
            switch kind {
            case .text, .url: text.count
            case .image, .file, .clip: 0
            }
        }

        public var searchText: String {
            [text, appName ?? "", kind.title, filePath ?? ""].joined(separator: " ")
        }

        /// Same normalized content, used to move a repeated copy to the front instead of adding
        /// a second card.
        func duplicates(_ other: Entry) -> Bool {
            switch kind {
            case .text, .url:
                return kind == other.kind && text == other.text
            case .image:
                guard kind == other.kind else { return false }
                if let imageHash, let otherHash = other.imageHash { return imageHash == otherHash }
                return imageFilename != nil && imageFilename == other.imageFilename
            case .file:
                return kind == other.kind && filePath == other.filePath
            case .clip:
                return kind == other.kind && text == other.text && appName == other.appName
            }
        }
    }

    /// Pinned first (newest pin first), then the rest, newest first.
    public private(set) var entries: [Entry] = []

    /// Unpinned copies kept. Pinned ones don't count towards it.
    public static let capacity = 20
    public static let pinnedCapacity = 20
    public static let maximumLength = 20_000
    /// This history's unpinned limit; Settings can change it.
    public var capacity: Int

    public init(pinned: [Entry] = [], capacity: Int = ClipboardHistory.capacity) {
        self.capacity = max(1, capacity)
        entries = Array(pinned.filter(\.isPinned).prefix(Self.pinnedCapacity))
    }

    public var pinned: [Entry] { entries.filter(\.isPinned) }
    public var pinnedCount: Int { entries.lazy.filter(\.isPinned).count }
    public var canPin: Bool { pinnedCount < Self.pinnedCapacity }

    /// Adds any kind of copy. Returns the id of the entry now in the history, which is the
    /// existing id when the same content was already there.
    @discardableResult
    public mutating func addEntry(_ entry: Entry, now: Date = Date()) -> UUID? {
        var incoming = entry
        if incoming.kind == .text || incoming.kind == .url {
            guard !incoming.isEmpty else { return nil }
            if incoming.text.count > Self.maximumLength {
                incoming.text = String(incoming.text.prefix(Self.maximumLength))
            }
        } else {
            guard !incoming.isEmpty else { return nil }
        }
        incoming.copiedAt = now

        if let index = entries.firstIndex(where: { $0.duplicates(incoming) }) {
            var existing = entries.remove(at: index)
            existing.copiedAt = now
            existing.kind = incoming.kind
            entries.insert(existing, at: existing.isPinned ? 0 : pinnedCount)
            trimUnpinned()
            return existing.id
        }

        entries.insert(incoming, at: pinnedCount)
        trimUnpinned()
        return incoming.id
    }

    /// Adds a text copy. Copying the same text again moves it to the front instead of repeating
    /// it, and a pinned clip stays pinned.
    @discardableResult
    public mutating func add(_ text: String, appName: String? = nil, now: Date = Date()) -> Bool {
        addEntry(Entry(text: text, appName: appName, copiedAt: now), now: now) != nil
    }

    /// Pins or unpins. A new pin goes to the top; an unpinned clip joins the history at the
    /// front. Returns false when the pins are full.
    @discardableResult
    public mutating func togglePin(_ id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        var entry = entries.remove(at: index)
        if entry.isPinned {
            entry.isPinned = false
            entries.insert(entry, at: pinnedCount)
            trimUnpinned()
            return true
        }
        guard canPin else {
            entries.insert(entry, at: index)
            return false
        }
        entry.isPinned = true
        entries.insert(entry, at: 0)
        return true
    }

    public mutating func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// Applies a new unpinned limit, dropping the oldest copies.
    public mutating func setCapacity(_ value: Int) {
        capacity = max(1, value)
        trimUnpinned()
    }

    private mutating func trimUnpinned() {
        let unpinned = entries.count - pinnedCount
        if unpinned > capacity {
            entries.removeLast(unpinned - capacity)
        }
    }

    /// Clears the history. Pinned clips stay unless `includingPinned`.
    public mutating func removeAll(includingPinned: Bool = false) {
        entries.removeAll { includingPinned || !$0.isPinned }
    }

    /// Entries whose text, file name, kind or app contains every word of the query, ignoring
    /// case and accents.
    public func matching(_ query: String) -> [Entry] {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return entries }
        return entries.filter { entry in
            words.allSatisfy { word in
                entry.searchText.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    /// One line for a compact card: whitespace runs collapsed, so code and lists stay readable.
    public static func preview(_ text: String, limit: Int = 200) -> String {
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return collapsed.count > limit ? String(collapsed.prefix(limit)) + "…" : collapsed
    }
}
