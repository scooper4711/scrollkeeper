import Foundation
import notify

/// The library as the other Tableside Toolkit apps see it: every title with a file, its editions and where they
/// are kept, written to `library.json` in Scrollkeeper's toolkit folder whenever it changes.
///
/// The format is a contract with those apps: see `docs/specs/app-handoff/design.md`.
public struct LibraryIndex: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var sku: String
        public var title: String
        /// The product type, such as "Adventures" or "Society Scenarios".
        public var kind: String
        /// The game, such as "Pathfinder 2E".
        public var gameSystem: String
        public var series: String?
        public var number: Int?
        public var levels: Levels?
        /// The cover's path in the toolkit folder, such as `Covers/PZO1E.jpg`; nil until one is stored.
        public var cover: String?
        /// True when an up-to-date copy is on disk.
        public var downloaded: Bool
        public var editions: [EditionEntry]
    }

    public struct Levels: Codable, Equatable, Sendable {
        public var lowest: Int
        public var highest: Int
    }

    public struct EditionEntry: Codable, Equatable, Sendable {
        public var name: String
        /// "Single File", "File per Chapter" and so on; nil when Paizo's name says nothing about it.
        public var kind: String?
        /// Where the edition is kept, relative to the download folder: `<title>/<edition>.<ext>`, or for an
        /// archive unpacked after download `<title>/<edition>`, a folder.
        public var path: String
        public var isFolder: Bool
        public var downloaded: Bool
        /// True when Paizo has updated the file since it was downloaded.
        public var outdated: Bool
    }

    /// Where the downloads are: the toolkit folder's `Files`, or a folder the user chose, whose path is given.
    public struct DownloadFolder: Codable, Equatable, Sendable {
        public var isShared: Bool
        public var path: String?
    }

    /// Raised when a change would break apps that read the list.
    public static let currentFormatVersion = 1
    public static let fileName = "library.json"
    /// The Darwin notification sent after each write, so readers can refresh without polling.
    public static let changeNotification = "io.github.scooper4711.tableside.library-changed"

    public var formatVersion = currentFormatVersion
    public var generatedAt: Date
    public var downloadFolder: DownloadFolder
    public var titles: [Entry]

    /// True when `other` lists the same titles in the same folder, whenever it was written.
    func hasSameContents(as other: LibraryIndex?) -> Bool {
        other.map { $0.downloadFolder == downloadFolder && $0.titles == titles } ?? false
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }
}

/// Makes the list's entries from the titles and what is on disk.
struct LibraryIndexBuilder {
    let locator: FileLocator
    /// The titles with a file on disk.
    let downloaded: Set<String>
    /// The titles with a file Paizo has updated since.
    let outdated: Set<String>
    /// The names of the stored covers; empty when the covers aren't in the toolkit folder.
    let covers: Set<String>

    /// The titles with an edition that can be fetched with one click, in title order.
    func entries(from items: [LibraryTitle]) -> [LibraryIndex.Entry] {
        items
            .filter { $0.editions.contains(where: \.isQuickDownloadable) }
            .sorted { $0.titleSortKey < $1.titleSortKey }
            .map(entry(for:))
    }

    private func entry(for item: LibraryTitle) -> LibraryIndex.Entry {
        let cover = CoverStore.fileName(sku: item.sku)
        return LibraryIndex.Entry(
            sku: item.sku,
            title: item.title,
            kind: item.productLineLabel,
            gameSystem: item.gameSystemLabel,
            series: item.series.isEmpty ? nil : item.series,
            number: item.classification.number,
            levels: item.classification.levelRange.map { LibraryIndex.Levels(lowest: $0.lowerBound,
                                                                             highest: $0.upperBound) },
            cover: covers.contains(cover) ? "Covers/" + cover : nil,
            downloaded: downloaded.contains(item.id) && !outdated.contains(item.id),
            editions: item.editions.filter(\.isQuickDownloadable).map { edition($0, in: item) }
        )
    }

    /// Only the editions of a title with files on disk are looked for, so a write stays quick.
    private func edition(_ edition: Edition, in item: LibraryTitle) -> LibraryIndex.EditionEntry {
        let target = locator.target(for: edition, in: item)
        let isOnDisk = downloaded.contains(item.id) && locator.isDownloaded(target)
        let file = target.localURL
        return LibraryIndex.EditionEntry(
            name: edition.entitlement.displayName,
            kind: edition.kind.label.isEmpty ? nil : edition.kind.label,
            path: file.deletingLastPathComponent().lastPathComponent + "/" + file.lastPathComponent,
            isFolder: target.isArchive,
            downloaded: isOnDisk,
            outdated: isOnDisk && locator.isOutdated(target)
        )
    }
}

extension LibraryEnvironment {
    /// Where the library list is written; nil outside the App Group, where no other app could read it.
    public var libraryIndexURL: URL? {
        toolkitFolder?.appending(path: LibraryIndex.fileName)
    }
}

extension LibraryStore {
    /// Writes the library list when it differs from the one last written, then tells the readers. Nothing is
    /// written before a catalog exists, so readers can tell "not synced yet" from "nothing to read".
    func writeLibraryIndexIfChanged() {
        guard let url = environment.libraryIndexURL, !items.isEmpty else { return }
        let index = LibraryIndex(generatedAt: environment.now(), downloadFolder: sharedDownloadFolder(),
                                 titles: libraryIndexBuilder().entries(from: items))
        guard !index.hasSameContents(as: writtenLibraryIndex) else { return }
        writtenLibraryIndex = index
        persist { _ in
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try index.encoded().write(to: url, options: .atomic)
            notify_post(LibraryIndex.changeNotification)
        }
    }

    private func libraryIndexBuilder() -> LibraryIndexBuilder {
        let coversAreShared = isInToolkitFolder(covers.directory, named: "Covers")
        return LibraryIndexBuilder(locator: locator, downloaded: downloadedItemIDs, outdated: outdatedItemIDs,
                                   covers: coversAreShared ? covers.storedFileNames() : [])
    }

    private func sharedDownloadFolder() -> LibraryIndex.DownloadFolder {
        let isShared = isInToolkitFolder(downloadDirectory, named: "Files")
        return LibraryIndex.DownloadFolder(isShared: isShared,
                                           path: isShared ? nil : downloadDirectory.path(percentEncoded: false))
    }

    /// True when `folder` is the toolkit folder's `name` folder.
    private func isInToolkitFolder(_ folder: URL, named name: String) -> Bool {
        guard let shared = environment.toolkitFolder?.appending(path: name) else { return false }
        return shared.standardizedFileURL.path == folder.standardizedFileURL.path
    }
}
