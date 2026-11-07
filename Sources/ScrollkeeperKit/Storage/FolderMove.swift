import Foundation

/// Moves one of Scrollkeeper's folders, such as the downloads, from the data folder into its folder in the
/// Tableside Toolkit's App Group (`ToolkitGroup.scrollkeeperFolder()`) the first time the app runs in the group.
/// Both are on the same volume, so a library of several gigabytes moves with one rename.
struct FolderMove {
    let fileManager = FileManager.default

    /// The folder to use from now on: `shared`, with the old folder's files moved into it, or `legacy` when they
    /// could not be moved.
    func destination(legacy: URL, shared: URL) -> URL {
        guard hasFiles(legacy), !hasFiles(shared) else { return shared }
        do {
            try fileManager.createDirectory(at: shared.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: shared.path) { try fileManager.removeItem(at: shared) }
            try fileManager.moveItem(at: legacy, to: shared)
            return shared
        } catch {
            return legacy
        }
    }

    private func hasFiles(_ folder: URL) -> Bool {
        let contents = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                            options: .skipsHiddenFiles)
        return !(contents ?? []).isEmpty
    }
}
