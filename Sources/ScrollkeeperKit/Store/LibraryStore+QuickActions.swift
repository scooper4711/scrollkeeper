import Foundation

/// What can be done with a title at a glance, without opening its details.
public struct TitleActions: Equatable, Sendable {
    /// The copy on disk to open, when there is one.
    public var open: DownloadTarget?
    /// The edition to download: the preferred one when nothing is on disk, or the copy on disk
    /// that Paizo has updated since.
    public var download: DownloadTarget?
    /// True when `download` replaces an out-of-date copy.
    public var isUpdate = false

    public init() {}
}

extension Edition {
    /// Lower is preferred when one edition has to be picked for the user: the single file over
    /// the chapters, a PDF over an ePub, full quality over lite.
    var downloadPreference: Int {
        switch kind {
        case .singleFile: 0
        case .filePerChapter: 2
        case .liteSingleFile: 3
        case .liteFilePerChapter: 4
        case .epub: 6
        case .other: entitlement.fileExtension == "pdf" ? 1 : 5
        }
    }

    /// False for editions that cannot be fetched with one click: those Paizo has attached no file
    /// to, and asset packs, which ask where to be saved.
    var isQuickDownloadable: Bool { entitlement.hasFile && !isSavedElsewhere }
}

extension LibraryStore {
    /// The quick actions for a title: what to open, and what to download or update.
    public func quickActions(for item: LibraryTitle) -> TitleActions {
        let editions = item.editions
            .filter(\.isQuickDownloadable)
            .sorted { $0.downloadPreference < $1.downloadPreference }
        let targets = editions.map { locator.target(for: $0, in: item) }
        let onDisk = targets.filter(locator.isDownloaded)
        var actions = TitleActions()
        actions.open = onDisk.first
        if let outdated = onDisk.first(where: locator.isOutdated) {
            actions.download = outdated
            actions.isUpdate = true
        } else if onDisk.isEmpty {
            actions.download = targets.first
        }
        return actions
    }

    /// What opening a download opens: the file itself, or for several unpacked files their folder.
    public func openableURL(for target: DownloadTarget) -> URL {
        let files = locator.files(in: target)
        return files.count == 1 ? files[0] : target.localURL
    }
}
