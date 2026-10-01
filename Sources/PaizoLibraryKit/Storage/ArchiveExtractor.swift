import Foundation

public struct ArchiveError: Error, Equatable, LocalizedError {
    public let archiveName: String
    public let detail: String

    public var errorDescription: String? {
        "Unpacking \(archiveName) failed: \(detail)"
    }
}

/// Unpacks zip archives with the system's `ditto` tool.
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
            try runDitto(arguments: ["-x", "-k", archive.path, staging.path], archiveName: archive.lastPathComponent)
            removeUploadPrefixes(in: staging)
            _ = try? FileManager.default.removeItem(at: directory)
            try FileManager.default.moveItem(at: staging, to: directory)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }

    private func removeUploadPrefixes(in directory: URL) {
        let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
        let files = enumerator?.compactMap { $0 as? URL } ?? []
        for file in files {
            let name = file.lastPathComponent
            let tidy = Self.uploadPrefix.removingMatches(in: name)
            let renamed = file.deletingLastPathComponent().appending(path: tidy)
            if tidy != name, !tidy.isEmpty, !FileManager.default.fileExists(atPath: renamed.path) {
                try? FileManager.default.moveItem(at: file, to: renamed)
            }
        }
    }

    private static let uploadPrefix = TextPattern(#"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-"#)

    private func runDitto(arguments: [String], archiveName: String) throws {
        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = arguments
        process.standardError = errors
        process.standardOutput = Pipe()
        try process.run()
        let message = String(bytes: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = message.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ArchiveError(archiveName: archiveName, detail: detail.isEmpty ? "the archive is damaged." : detail)
        }
    }
}
