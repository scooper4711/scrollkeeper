import Foundation
@testable import ScrollkeeperKit
import Testing

@Suite struct ToolkitFolderTests {
    @Test func findsTheToolkitGroupAmongTheSignedGroups() {
        let groups = ["ABCDE12345.io.github.scooper4711.other", "ABCDE12345.io.github.scooper4711.tableside"]
        #expect(ToolkitFolder.tablesideGroup(in: groups) == "ABCDE12345.io.github.scooper4711.tableside")
    }

    @Test func hasNoGroupWhenUnsignedOrOutsideTheToolkit() {
        #expect(ToolkitFolder.tablesideGroup(in: []) == nil)
        #expect(ToolkitFolder.tablesideGroup(in: ["group.example.other"]) == nil)
    }

    @Test func testsRunOutsideTheGroup() {
        #expect(ToolkitFolder.url() == nil)
    }
}

@Suite struct FolderMoveTests {
    private let directory = TemporaryDirectory()
    private var legacy: URL { directory.url.appending(path: "Application Support/Scrollkeeper/Files") }
    private var shared: URL { directory.url.appending(path: "Group Containers/tableside/Scrollkeeper/Files") }

    @Test func movesTheOldDownloadsIntoTheSharedFolder() throws {
        try write("Book/Book.pdf", in: legacy)

        #expect(FolderMove().destination(legacy: legacy, shared: shared) == shared)
        #expect(try String(contentsOf: shared.appending(path: "Book/Book.pdf"), encoding: .utf8) == "Book/Book.pdf")
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test func replacesAnEmptySharedFolder() throws {
        try write("Book/Book.pdf", in: legacy)
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        try Data().write(to: shared.appending(path: ".DS_Store"))

        #expect(FolderMove().destination(legacy: legacy, shared: shared) == shared)
        #expect(FileManager.default.fileExists(atPath: shared.appending(path: "Book/Book.pdf").path))
    }

    @Test func usesTheSharedFolderWhenThereIsNothingToMove() {
        #expect(FolderMove().destination(legacy: legacy, shared: shared) == shared)
        #expect(!FileManager.default.fileExists(atPath: shared.path))
    }

    @Test func leavesTheOldFolderAloneOnceTheSharedFolderHasFiles() throws {
        try write("Old/Old.pdf", in: legacy)
        try write("New/New.pdf", in: shared)

        #expect(FolderMove().destination(legacy: legacy, shared: shared) == shared)
        #expect(FileManager.default.fileExists(atPath: legacy.appending(path: "Old/Old.pdf").path))
        #expect(!FileManager.default.fileExists(atPath: shared.appending(path: "Old").path))
    }

    @Test func keepsTheOldFolderWhenTheMoveFails() throws {
        try write("Book/Book.pdf", in: legacy)
        let blocked = directory.url.appending(path: "Group Containers")
        try Data().write(to: blocked)

        #expect(FolderMove().destination(legacy: legacy, shared: shared) == legacy)
        #expect(FileManager.default.fileExists(atPath: legacy.appending(path: "Book/Book.pdf").path))
    }

    /// Writes a file holding its own relative path.
    private func write(_ path: String, in folder: URL) throws {
        let file = folder.appending(path: path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(path.utf8).write(to: file)
    }
}

@Suite struct ToolkitFolderEnvironmentTests {
    private let directory = TemporaryDirectory()

    @Test func movesTheDownloadsAndCoversIntoTheToolkitFolder() throws {
        var environment = LibraryEnvironment.demo()
        environment.dataDirectory = directory.url.appending(path: "data")
        environment.defaultDownloadDirectory = directory.url.appending(path: "data/Files")
        environment.coversDirectory = directory.url.appending(path: "data/Covers")
        try FileManager.default.createDirectory(at: environment.defaultDownloadDirectory.appending(path: "Book"),
                                                withIntermediateDirectories: true)
        CoverStore(directory: environment.coversDirectory).store(Data("cover".utf8), sku: "PZO1E")
        let toolkit = directory.url.appending(path: "toolkit")

        environment.useToolkitFolder(toolkit)

        #expect(environment.toolkitFolder == toolkit)
        #expect(environment.defaultDownloadDirectory.path == toolkit.appending(path: "Files").path)
        #expect(environment.coversDirectory.path == toolkit.appending(path: "Covers").path)
        #expect(CoverStore(directory: environment.coversDirectory).hasCover(sku: "PZO1E"))
    }

    @Test func demoModeSharesNothing() {
        #expect(LibraryEnvironment.demo().toolkitFolder == nil)
        #expect(LibraryEnvironment.demo().libraryIndexURL == nil)
    }
}
