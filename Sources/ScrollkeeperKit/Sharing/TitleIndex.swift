import Foundation

/// The titles the user owns that an app can open, written when the app asks (`scrollkeeper://index`) and
/// handed to it as a file, which a sandboxed app is given access to.
///
/// The format is a contract with those apps: see `docs/specs/app-handoff/design.md`.
public struct TitleIndex: Codable, Equatable, Sendable {
    /// One title the app can ask Scrollkeeper to open.
    public struct Entry: Codable, Equatable, Sendable {
        public var sku: String
        public var title: String
        /// The product type, such as "Adventures" or "Society Scenarios".
        public var kind: String
        public var series: String?
        public var number: Int?
        /// True when an up-to-date copy is on disk, so opening it needs no download.
        public var downloaded: Bool
    }

    /// Raised when a change would break apps that read the index.
    public static let currentFormatVersion = 1
    public static let fileExtension = "scrollkeeperindex"

    public var formatVersion = currentFormatVersion
    public var generatedAt: Date
    public var titles: [Entry]

    /// The titles with a one-click edition `app` can open, in title order. `downloaded` holds the titles
    /// with an up-to-date copy on disk.
    public static func entries(from items: [LibraryTitle], downloaded: Set<String>, for app: HandoffApp) -> [Entry] {
        items
            .filter { item in item.editions.contains { $0.isQuickDownloadable && app.canOpen($0) } }
            .sorted { $0.titleSortKey < $1.titleSortKey }
            .map { item in
                Entry(
                    sku: item.sku,
                    title: item.title,
                    kind: item.classification.productLine.label,
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
    /// Where the list for `app` is written before it is handed over.
    public func titleIndexURL(for app: HandoffApp) -> URL {
        sharedDirectory.appending(path: "\(app.rawValue).\(TitleIndex.fileExtension)")
    }
}
