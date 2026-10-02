import Foundation

/// A file that can be downloaded, and where it lives on disk once it has been.
///
/// For a PDF edition a zip archive is only the means of delivery: it is unpacked into a folder
/// and then removed, so for such an archive `localURL` is that folder.
public struct DownloadTarget: Sendable, Hashable, Identifiable {
    public let itemID: String
    public let remote: RemoteFile
    public let localURL: URL
    public let isArchive: Bool

    public var id: String { localURL.path }

    /// Where the download is kept until it is complete.
    public var partialURL: URL {
        localURL.deletingLastPathComponent()
            .appending(path: localURL.lastPathComponent + "." + FileLocator.partialExtension)
    }

    public static func == (lhs: DownloadTarget, rhs: DownloadTarget) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Decides where downloaded files are kept: `<root>/<title>/<edition>.<ext>`, or
/// `<root>/<title>/<edition>/` for the contents of an archive.
///
/// Paths are derived from entitlement data only, so a file counts as downloaded when it exists.
public struct FileLocator: Sendable {
    static let partialExtension = "download"

    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public func folder(for item: LibraryTitle) -> URL {
        root.appending(path: FileNameSanitizer.sanitize(item.title), directoryHint: .isDirectory)
    }

    public func target(for edition: Edition, in item: LibraryTitle) -> DownloadTarget {
        let name = baseName(for: edition, in: item)
        let localURL = edition.isUnpackedArchive
            ? folder(for: item).appending(path: name, directoryHint: .isDirectory)
            : folder(for: item).appending(path: suggestedFileName(for: edition, in: item))
        return DownloadTarget(
            itemID: item.id,
            remote: RemoteFile(entitlement: edition.entitlement),
            localURL: localURL,
            isArchive: edition.isUnpackedArchive
        )
    }

    /// A download that goes to a place the user chose and is not kept in the library folder.
    public func exportTarget(for edition: Edition, in item: LibraryTitle, destination: URL) -> DownloadTarget {
        DownloadTarget(
            itemID: item.id,
            remote: RemoteFile(entitlement: edition.entitlement),
            localURL: destination,
            isArchive: false
        )
    }

    /// The file name offered when the user is asked where to save an edition.
    public func suggestedFileName(for edition: Edition, in item: LibraryTitle) -> String {
        let fileExtension = edition.entitlement.fileExtension
        let name = baseName(for: edition, in: item)
        return fileExtension.isEmpty ? name : name + "." + fileExtension
    }

    public func isDownloaded(_ target: DownloadTarget) -> Bool {
        !files(in: target).isEmpty
    }

    /// The downloaded file, or the unpacked files of an archive in name order. Empty when not downloaded.
    public func files(in target: DownloadTarget) -> [URL] {
        if target.isArchive {
            return regularFiles(under: target.localURL)
        }
        return FileManager.default.fileExists(atPath: target.localURL.path) ? [target.localURL] : []
    }

    /// Every finished file of the title, including the contents of unpacked archives.
    public func localFiles(for item: LibraryTitle) -> [URL] {
        regularFiles(under: folder(for: item))
    }

    /// The titles that have at least one finished file, found with a single listing of the root.
    public func downloadedItemIDs(among items: [LibraryTitle]) -> Set<String> {
        let folders = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        let existing = Set(folders)
        let candidates = items.filter { existing.contains(FileNameSanitizer.sanitize($0.title)) }
        return Set(candidates.filter { !localFiles(for: $0).isEmpty }.map(\.id))
    }

    /// Regular files below `directory`, skipping hidden ones and downloads still in progress.
    private func regularFiles(under directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )
        let urls = enumerator?.compactMap { $0 as? URL } ?? []
        let files = urls.filter { url in
            let isFile = (try? url.resourceValues(forKeys: Set(keys)).isRegularFile) ?? false
            return isFile && url.pathExtension != Self.partialExtension
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Entitlements of one title can share a name; those get part of their identifier appended.
    private func baseName(for edition: Edition, in item: LibraryTitle) -> String {
        let name = edition.entitlement.displayName
        let isAmbiguous = item.editions.filter { $0.entitlement.displayName == name }.count > 1
        let unique = isAmbiguous ? "\(name) (\(edition.entitlement.packageID.prefix(8)))" : name
        return FileNameSanitizer.sanitize(unique)
    }
}
