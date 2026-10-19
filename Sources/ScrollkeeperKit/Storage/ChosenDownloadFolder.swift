import Foundation

/// The folder the user chose for downloads. It is remembered as a bookmark as well as a path: on the Mac a
/// security-scoped bookmark is what lets the app reach the folder again from inside the App Sandbox, and it
/// follows the folder when it is moved or renamed.
///
/// A folder chosen before bookmarks were kept has only its path. It gets a bookmark the first time the app
/// reads it, while the app still runs outside the sandbox and can reach it.
struct ChosenDownloadFolder {
    let settings: SettingsStore

    /// The chosen folder, with access to it until the app quits; nil when downloads go to the default folder.
    func open() -> URL? {
        if let folder = resolvedBookmark() { return folder }
        let path = settings.downloadDirectoryPath
        guard !path.isEmpty else { return nil }
        let folder = URL(filePath: path, directoryHint: .isDirectory)
        // A bookmark that no longer resolves may be for a disk that isn't connected; keep it for when it is.
        if settings.downloadDirectoryBookmark == nil {
            settings.downloadDirectoryBookmark = Self.bookmark(for: folder)
        }
        return folder
    }

    func remember(_ folder: URL) {
        settings.downloadDirectoryPath = folder.path
        settings.downloadDirectoryBookmark = Self.bookmark(for: folder)
    }

    func forget() {
        settings.downloadDirectoryPath = ""
        settings.downloadDirectoryBookmark = nil
    }

    private func resolvedBookmark() -> URL? {
        guard let bookmark = settings.downloadDirectoryBookmark else { return nil }
        var isStale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, options: Self.resolutionOptions,
                                    relativeTo: nil, bookmarkDataIsStale: &isStale)
        else { return nil }
        _ = folder.startAccessingSecurityScopedResource()
        if isStale {
            remember(folder)
        } else if folder.path != settings.downloadDirectoryPath {
            settings.downloadDirectoryPath = folder.path
        }
        return folder
    }

    private static func bookmark(for folder: URL) -> Data? {
        try? folder.bookmarkData(options: creationOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    #if os(macOS)
    private static let creationOptions: URL.BookmarkCreationOptions = .withSecurityScope
    private static let resolutionOptions: URL.BookmarkResolutionOptions = .withSecurityScope
    #else
    private static let creationOptions: URL.BookmarkCreationOptions = []
    private static let resolutionOptions: URL.BookmarkResolutionOptions = []
    #endif
}
