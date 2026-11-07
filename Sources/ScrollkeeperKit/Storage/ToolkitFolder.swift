import Foundation
#if os(macOS)
import Security
#endif

/// Scrollkeeper's folder in the Tableside Toolkit's App Group (requirements 5 of the app-handoff spec):
/// `~/Library/Group Containers/<team ID>.io.github.scooper4711.tableside/Scrollkeeper`. It holds the downloads
/// (`Files`), the cover artwork (`Covers`) and the list of the library (`library.json`). Only Scrollkeeper writes
/// there; the other toolkit apps read it.
public enum ToolkitFolder {
    /// The group's name after the team ID. The team ID isn't committed: `scripts/build-app.sh` fills it in.
    static let groupSuffix = ".io.github.scooper4711.tableside"

    /// The folder, or nil when the app isn't signed into the group: an ad hoc development build, the iPad, or a
    /// run outside an app bundle such as the tests.
    public static func url() -> URL? {
        guard let group = tablesideGroup(in: signedGroups()),
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { return nil }
        return container.appending(path: "Scrollkeeper", directoryHint: .isDirectory)
    }

    /// The toolkit's group among those the app is signed with.
    static func tablesideGroup(in groups: [String]) -> String? {
        groups.first { $0.hasSuffix(groupSuffix) }
    }

    /// The App Groups in the app's own entitlements, which name the team the app was signed by.
    private static func signedGroups() -> [String] {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil)
        else { return [] }
        return value as? [String] ?? []
        #else
        return []
        #endif
    }
}

/// Moves one of Scrollkeeper's folders, such as the downloads, from the data folder into the toolkit folder the
/// first time the app runs in the App Group. Both are on the same volume, so a library of several gigabytes moves
/// with one rename.
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
