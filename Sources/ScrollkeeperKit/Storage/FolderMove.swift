import Foundation

/// Moves the contents of one of Scrollkeeper's folders, such as the downloads, from its old place (the data folder on
/// a Mac, the Documents folder on an iPad) into its folder in the Tableside Toolkit's App Group
/// (`ToolkitGroup.scrollkeeperFolder()`) the first time the app runs in the group. Both are on the same volume, so a
/// library of several gigabytes moves with a rename per item. The old folder itself stays, empty: an iPad's
/// Documents folder can't be moved.
struct FolderMove {
    let fileManager = FileManager.default

    /// The folder to use from now on: `shared`, with the old folder's files moved into it, or `legacy` when they
    /// could not all be moved, in which case those already moved go back.
    func destination(legacy: URL, shared: URL) -> URL {
        let items = visibleItems(in: legacy)
        guard !items.isEmpty, visibleItems(in: shared).isEmpty else { return shared }
        var moved: [URL] = []
        do {
            try fileManager.createDirectory(at: shared, withIntermediateDirectories: true)
            for item in items {
                try fileManager.moveItem(at: item, to: shared.appending(path: item.lastPathComponent))
                moved.append(item)
            }
            return shared
        } catch {
            moveBack(moved, from: shared)
            return legacy
        }
    }

    private func moveBack(_ items: [URL], from shared: URL) {
        for item in items {
            try? fileManager.moveItem(at: shared.appending(path: item.lastPathComponent), to: item)
        }
    }

    private func visibleItems(in folder: URL) -> [URL] {
        let contents = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil,
                                                            options: .skipsHiddenFiles)
        // In name order, so a failed move always leaves the same items behind.
        return (contents ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
