import Foundation
import ZIPFoundation

public struct ArchiveError: Error, Equatable, LocalizedError {
    public let archiveName: String
    public let detail: String

    public var errorDescription: String? {
        "Unpacking \(archiveName) failed: \(detail)"
    }
}

/// Unpacks zip archives.
public struct ArchiveExtractor: Sendable {
    public init() {}

    /// Unpacks `archive` into `directory`, replacing it. The directory only appears once the
    /// whole archive has been unpacked. Paizo prefixes file names with an upload identifier
    /// (`beb8a193-…-PZO15223E.pdf`); the prefix is removed.
    public func extract(_ archive: URL, to directory: URL) throws {
        let staging = directory.deletingLastPathComponent()
            .appending(path: "." + directory.lastPathComponent + ".unpacking", directoryHint: .isDirectory)
        _ = try? FileManager.default.removeItem(at: staging)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            try unzip(archive, to: staging)
            tidy(staging)
            _ = try? FileManager.default.removeItem(at: directory)
            try FileManager.default.moveItem(at: staging, to: directory)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }

    private func unzip(_ archive: URL, to directory: URL) throws {
        do {
            try FileManager.default.unzipItem(at: archive, to: directory)
        } catch {
            throw ArchiveError(archiveName: archive.lastPathComponent, detail: Self.describe(error))
        }
    }

    private static func describe(_ error: Error) -> String {
        error is Archive.ArchiveError ? "the archive is damaged." : error.localizedDescription
    }

    /// Removes the resource-fork folder some archives made on a Mac carry, and the upload prefixes.
    private func tidy(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory.appending(path: "__MACOSX"))
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        let files = enumerator?.compactMap { $0 as? URL } ?? []
        for file in files {
            let name = file.lastPathComponent
            let tidyName = Self.uploadPrefix.removingMatches(in: name)
            let renamed = file.deletingLastPathComponent().appending(path: tidyName)
            if tidyName != name, !tidyName.isEmpty, !FileManager.default.fileExists(atPath: renamed.path) {
                try? FileManager.default.moveItem(at: file, to: renamed)
            }
        }
    }

    private static let uploadPrefix = TextPattern(#"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-"#)
}
