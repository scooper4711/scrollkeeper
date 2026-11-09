import Foundation
import TablesideShared

/// When the demo library shares through the Tableside Toolkit's App Group (library-manager 13.7): only when no real
/// library is there, marking what it shares as the demo's, so a real launch removes it before using the folder.
enum DemoSharing {
    /// The file beside `library.json` that says the folder's contents are the demo's.
    static let markName = ".demo-library"
    private static let sharedNames = ["Files", "Covers", ScrollkeeperLibrary.fileName, markName]

    /// True when the demo may share through Scrollkeeper's `folder`: it already did, or the folder holds no library
    /// list and no downloads.
    static func canShare(in folder: URL) -> Bool {
        let manager = FileManager.default
        if manager.fileExists(atPath: folder.appending(path: markName).path) { return true }
        let files = (try? manager.contentsOfDirectory(atPath: folder.appending(path: "Files").path)) ?? []
        return !manager.fileExists(atPath: folder.appending(path: ScrollkeeperLibrary.fileName).path)
            && !files.contains { !$0.hasPrefix(".") }
    }

    /// Marks `folder`'s contents as the demo's.
    static func claim(_ folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appending(path: markName))
    }

    /// Removes what the demo shared from `folder`, if anything; a real library's folder is left alone.
    static func removeDemo(from folder: URL) {
        guard FileManager.default.fileExists(atPath: folder.appending(path: markName).path) else { return }
        for name in sharedNames {
            try? FileManager.default.removeItem(at: folder.appending(path: name))
        }
    }
}
