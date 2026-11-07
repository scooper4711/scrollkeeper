import Foundation
import TablesideShared

/// Scrollkeeper's side of the library list it shares with the other Tableside Toolkit apps: `library.json` in its
/// folder in the App Group, whose format `TablesideShared.ScrollkeeperLibrary` defines for writer and readers alike.
/// See `docs/specs/app-handoff/design.md`.
extension ScrollkeeperLibrary {
    /// True when `other` lists the same titles in the same folder, whenever it was written.
    func hasSameContents(as other: ScrollkeeperLibrary?) -> Bool {
        other.map { $0.downloadFolder == downloadFolder && $0.titles == titles } ?? false
    }
}

/// Makes the list's titles from the library and what is on disk.
struct LibraryIndexBuilder {
    let locator: FileLocator
    /// The titles with a file on disk.
    let downloaded: Set<String>
    /// The titles with a file Paizo has updated since.
    let outdated: Set<String>
    /// The names of the stored covers; empty when the covers aren't in the toolkit folder.
    let covers: Set<String>

    /// The titles with an edition that can be fetched with one click, in title order.
    func titles(from items: [LibraryTitle]) -> [ScrollkeeperLibrary.Title] {
        items
            .filter { $0.editions.contains(where: \.isQuickDownloadable) }
            .sorted { $0.titleSortKey < $1.titleSortKey }
            .map(title(for:))
    }

    private func title(for item: LibraryTitle) -> ScrollkeeperLibrary.Title {
        let cover = CoverStore.fileName(sku: item.sku)
        return ScrollkeeperLibrary.Title(
            sku: item.sku,
            title: item.title,
            kind: item.productLineLabel,
            gameSystem: item.gameSystemLabel,
            series: item.series.isEmpty ? nil : item.series,
            number: item.classification.number,
            levels: item.classification.levelRange.map { ScrollkeeperLibrary.Levels(lowest: $0.lowerBound,
                                                                                    highest: $0.upperBound) },
            cover: covers.contains(cover) ? "Covers/" + cover : nil,
            downloaded: downloaded.contains(item.id) && !outdated.contains(item.id),
            editions: item.editions.filter(\.isQuickDownloadable).map { edition($0, in: item) }
        )
    }

    /// Only the editions of a title with files on disk are looked for, so a write stays quick.
    private func edition(_ edition: Edition, in item: LibraryTitle) -> ScrollkeeperLibrary.Edition {
        let target = locator.target(for: edition, in: item)
        let isOnDisk = downloaded.contains(item.id) && locator.isDownloaded(target)
        let file = target.localURL
        return ScrollkeeperLibrary.Edition(
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
        toolkitFolder?.appending(path: ScrollkeeperLibrary.fileName)
    }
}

extension LibraryStore {
    /// Writes the library list when it differs from the one last written, then tells the readers. Nothing is
    /// written before a catalog exists, so readers can tell "not synced yet" from "nothing to read".
    func writeLibraryIndexIfChanged() {
        guard let url = environment.libraryIndexURL, !items.isEmpty else { return }
        let index = ScrollkeeperLibrary(generatedAt: environment.now(), downloadFolder: sharedDownloadFolder(),
                                        titles: libraryIndexBuilder().titles(from: items))
        guard !index.hasSameContents(as: writtenLibraryIndex) else { return }
        writtenLibraryIndex = index
        persist { _ in
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try index.encoded().write(to: url, options: .atomic)
            LibraryChange.post()
        }
    }

    private func libraryIndexBuilder() -> LibraryIndexBuilder {
        let coversAreShared = isInToolkitFolder(covers.directory, named: "Covers")
        return LibraryIndexBuilder(locator: locator, downloaded: downloadedItemIDs, outdated: outdatedItemIDs,
                                   covers: coversAreShared ? covers.storedFileNames() : [])
    }

    private func sharedDownloadFolder() -> ScrollkeeperLibrary.DownloadFolder {
        let isShared = isInToolkitFolder(downloadDirectory, named: "Files")
        return ScrollkeeperLibrary.DownloadFolder(isShared: isShared,
                                                  path: isShared ? nil : downloadDirectory.path(percentEncoded: false))
    }

    /// True when `folder` is the toolkit folder's `name` folder.
    private func isInToolkitFolder(_ folder: URL, named name: String) -> Bool {
        guard let shared = environment.toolkitFolder?.appending(path: name) else { return false }
        return shared.standardizedFileURL.path == folder.standardizedFileURL.path
    }
}
