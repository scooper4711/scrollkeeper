import Foundation

/// The map titles the user owns, written for other Tableside Toolkit apps to search.
///
/// The format is a contract with those apps: see `docs/specs/app-handoff/design.md`.
public struct MapIndex: Codable, Equatable, Sendable {
    /// One map title a requesting app can ask Scrollkeeper to open.
    public struct Entry: Codable, Equatable, Sendable {
        public var sku: String
        public var title: String
        public var series: String?
        public var number: Int?
        /// True when an up-to-date copy is on disk, so opening it needs no download.
        public var downloaded: Bool
    }

    /// Raised when a change would break apps that read the index.
    public static let currentFormatVersion = 1
    public static let fileName = "maps.json"

    public var formatVersion = currentFormatVersion
    public var generatedAt: Date
    public var titles: [Entry]

    /// The entries for the map titles that can be fetched with one click, in title order.
    /// `downloaded` holds the titles with an up-to-date copy on disk.
    public static func entries(from items: [LibraryTitle], downloaded: Set<String>) -> [Entry] {
        items
            .filter { $0.classification.productLine == .maps && $0.editions.contains(where: \.isQuickDownloadable) }
            .sorted { $0.titleSortKey < $1.titleSortKey }
            .map { item in
                Entry(
                    sku: item.sku,
                    title: item.title,
                    series: item.series.isEmpty ? nil : item.series,
                    number: item.classification.number,
                    downloaded: downloaded.contains(item.id)
                )
            }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

extension LibraryEnvironment {
    /// Files Scrollkeeper writes for other apps to read.
    public var sharedDirectory: URL {
        dataDirectory.appending(path: "Shared", directoryHint: .isDirectory)
    }

    public var mapIndexURL: URL {
        sharedDirectory.appending(path: MapIndex.fileName)
    }
}

extension LibraryStore {
    /// Writes the map index when its entries differ from those last written. Nothing is written
    /// before a catalog exists, so requesting apps can tell "not synced yet" from "no maps".
    func writeMapIndexIfChanged() {
        guard !items.isEmpty else { return }
        let entries = MapIndex.entries(from: items, downloaded: downloadedItemIDs.subtracting(outdatedItemIDs))
        guard entries != writtenMapEntries else { return }
        writtenMapEntries = entries
        let index = MapIndex(generatedAt: environment.now(), titles: entries)
        let url = environment.mapIndexURL
        persist { _ in
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try index.encoded().write(to: url, options: .atomic)
        }
    }
}
