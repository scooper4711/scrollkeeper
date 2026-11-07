import Foundation
import notify
@testable import ScrollkeeperKit
import Testing

@MainActor
@Suite struct LibraryIndexTests {
    private let harness: StoreHarness

    init() {
        harness = StoreHarness()
        harness.usesToolkitFolder = true
    }

    private func readIndex() throws -> LibraryIndex {
        let url = try #require(harness.environment.libraryIndexURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LibraryIndex.self, from: Data(contentsOf: url))
    }

    private func entry(_ sku: String) throws -> LibraryIndex.Entry {
        try #require(try readIndex().titles.first { $0.sku == sku })
    }

    @Test func listsEveryTitleWithItsEditionsInTheSharedFolder() async throws {
        _ = await harness.makeSyncedStore()

        let index = try readIndex()
        #expect(index.formatVersion == LibraryIndex.currentFormatVersion)
        #expect(index.generatedAt == harness.clock.now)
        #expect(index.downloadFolder == LibraryIndex.DownloadFolder(isShared: true, path: nil))
        #expect(Set(index.titles.map(\.sku)) == ["PZO1E", "PZO2E"])

        let book = try entry("PZO1E")
        #expect(book.editions.count == 2)
        #expect(book.editions.map(\.isFolder).sorted { !$0 && $1 } == [false, true])
        #expect(book.editions.allSatisfy { $0.path.hasPrefix(book.title) && !$0.downloaded && !$0.outdated })
        #expect(!book.downloaded)
    }

    @Test func marksTheEditionsOnDiskWithPathsReadersCanFollow() async throws {
        let store = await harness.makeSyncedStore()
        let item = try #require(store.item(id: "PZO2E"))
        store.download(try #require(store.quickActions(for: item).download))
        await store.waitForDownloads()
        await store.waitUntilIdle()

        let map = try entry("PZO2E")
        let edition = try #require(map.editions.first)
        #expect(map.downloaded)
        #expect(edition.downloaded && !edition.outdated)
        let file = harness.toolkitFolder.appending(path: "Files").appending(path: edition.path)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func pointsToTheCoverOnceOneIsStored() async throws {
        let store = await harness.makeSyncedStore()
        #expect(try entry("PZO2E").cover == nil)

        store.covers.store(Data("cover".utf8), sku: "PZO2E")
        store.rebuildItems()
        await store.waitUntilIdle()

        let cover = try #require(try entry("PZO2E").cover)
        #expect(cover == "Covers/PZO2E.jpg")
        #expect(FileManager.default.fileExists(atPath: harness.toolkitFolder.appending(path: cover).path))
    }

    @Test func givesThePathOfAFolderTheUserChose() async throws {
        let store = await harness.makeSyncedStore()
        let chosen = harness.directory.url.appending(path: "Chosen", directoryHint: .isDirectory)

        store.setDownloadDirectory(chosen)
        await store.waitUntilIdle()

        #expect(try readIndex().downloadFolder.path == chosen.path(percentEncoded: false))
        #expect(try !readIndex().downloadFolder.isShared)
    }

    @Test func isRewrittenOnlyWhenItsContentsChange() async throws {
        let store = await harness.makeSyncedStore()
        let url = try #require(harness.environment.libraryIndexURL)
        try FileManager.default.removeItem(at: url)

        harness.clock.advance(by: 60)
        store.rebuildItems()
        await store.waitUntilIdle()

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func tellsTheReadersAfterEachWrite() async throws {
        var token: Int32 = 0
        #expect(notify_register_check(LibraryIndex.changeNotification, &token) == NOTIFY_STATUS_OK)
        defer { notify_cancel(token) }
        var changed: Int32 = 0
        notify_check(token, &changed)

        _ = await harness.makeSyncedStore()

        notify_check(token, &changed)
        #expect(changed == 1)
    }

    @Test func writesNothingBeforeACatalogExists() async throws {
        let empty = StoreHarness(account: nil, records: [])
        empty.usesToolkitFolder = true
        let store = empty.makeStore()
        await store.start()
        await store.waitUntilIdle()

        let url = try #require(empty.environment.libraryIndexURL)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func writesNothingOutsideTheAppGroup() async {
        let outside = StoreHarness()
        _ = await outside.makeSyncedStore()

        #expect(outside.environment.libraryIndexURL == nil)
        #expect(!FileManager.default.fileExists(atPath: outside.toolkitFolder.path))
    }
}
