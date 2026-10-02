import Foundation
@testable import ScrollkeeperKit
import Testing

@MainActor
@Suite struct LibraryStoreDownloadTests {
    private let harness = StoreHarness()

    private func singleFileTarget(in store: LibraryStore) throws -> DownloadTarget {
        let item = try #require(store.item(id: "PZO1E"))
        return store.locator.target(for: item.editions[0], in: item)
    }

    @Test func downloadSavesTheFileAndMarksTheTitleDownloaded() async throws {
        let store = await harness.makeSyncedStore()
        let target = try singleFileTarget(in: store)
        #expect(!store.isDownloaded(target))

        store.download(target)
        store.download(target)
        #expect(store.downloads[target.id] == .inProgress(0))
        await store.waitForDownloads()

        #expect(store.isDownloaded(target))
        #expect(try String(contentsOf: target.localURL, encoding: .utf8) == "%PDF-fake")
        #expect(store.downloads[target.id] == nil)
        #expect(store.downloadedItemIDs == ["PZO1E"])
        #expect(store.facets.downloaded == 1)
        #expect(target.localURL.path.hasPrefix(store.downloadDirectory.path))
        #expect(harness.paizo.http.count(of: "https://s3.example/signed") == 1)
    }

    @Test func failedDownloadExplainsAndLeavesNoPartialFile() async throws {
        let store = await harness.makeSyncedStore()
        let target = try singleFileTarget(in: store)
        harness.paizo.http.on("https://s3.example/signed", text: "denied", status: 403)

        store.download(target)
        await store.waitForDownloads()

        #expect(store.downloads[target.id] == .failed("Downloading the file failed: Paizo answered with status 403."))
        #expect(!store.isDownloaded(target))
        #expect(store.locator.localFiles(for: try #require(store.item(id: "PZO1E"))).isEmpty)
    }

    @Test func deletingADownloadRemovesItFromDisk() async throws {
        let store = await harness.makeSyncedStore()
        let target = try singleFileTarget(in: store)
        store.download(target)
        await store.waitForDownloads()

        store.deleteDownload(target)

        #expect(!store.isDownloaded(target))
        #expect(store.downloadedItemIDs.isEmpty)
    }

    @Test func canceledDownloadLeavesNoFailure() async throws {
        let store = await harness.makeSyncedStore()
        let target = try singleFileTarget(in: store)

        store.download(target)
        store.cancelDownload(target)
        await store.waitForDownloads()

        #expect(store.downloads[target.id] != .inProgress(0))
    }

    @Test func archiveIsUnpackedIntoItsFolderAndTheZipIsRemoved() async throws {
        let store = await harness.makeSyncedStore()
        let zip = try Fixtures.zipArchive(files: ["01 Intro.pdf": "intro", "02 Classes.pdf": "classes"])
        harness.paizo.http.on("https://s3.example/signed", data: zip)
        let item = try #require(store.item(id: "PZO1E"))
        let target = store.locator.target(for: item.editions[1], in: item)
        store.addTag("Campaign", to: "PZO1E")

        store.download(target)
        await store.waitForDownloads()

        let files = store.files(in: target)
        #expect(files.map(\.lastPathComponent) == ["01 Intro.pdf", "02 Classes.pdf"])
        #expect(try String(contentsOf: files[0], encoding: .utf8) == "intro")
        #expect(FinderTagger().tags(of: files[1]) == ["Campaign"])
        #expect(!FileManager.default.fileExists(atPath: target.partialURL.path))
        #expect(store.isDownloaded(target))
        #expect(store.downloads[target.id] == nil)

        store.deleteDownload(target)
        #expect(store.files(in: target).isEmpty)
    }

    @Test func otherZipIsSavedWhereAskedAndNotKeptInTheLibrary() async throws {
        let records = [Fixtures.record(id: "runes", name: "Community Use Package: Runes", sku: "PZOCUP1E",
                                       file: "runes.zip")]
        let community = StoreHarness(records: records)
        let store = await community.makeSyncedStore()
        let item = try #require(store.item(id: "PZOCUP1E"))
        let destination = community.directory.url.appending(path: "Desktop/Runes.zip")

        let target = store.export(item.editions[0], of: item, to: destination)
        await store.waitForDownloads()

        #expect(try String(contentsOf: destination, encoding: .utf8) == "%PDF-fake")
        #expect(store.downloads[target.id] == nil)
        #expect(store.downloadedItemIDs.isEmpty)
        #expect(store.locator.localFiles(for: item).isEmpty)
    }

    @Test func damagedArchiveIsReportedAndRemoved() async throws {
        let store = await harness.makeSyncedStore()
        harness.paizo.http.on("https://s3.example/signed", text: "not a zip")
        let item = try #require(store.item(id: "PZO1E"))
        let target = store.locator.target(for: item.editions[1], in: item)

        store.download(target)
        await store.waitForDownloads()

        guard case let .failed(message) = store.downloads[target.id] else {
            Issue.record("the damaged archive was not reported")
            return
        }
        #expect(message.hasPrefix("Unpacking "))
        #expect(!store.isDownloaded(target))
        #expect(!FileManager.default.fileExists(atPath: target.partialURL.path))
    }

    @Test func downloadFolderCanBeChangedAndReset() async throws {
        let store = await harness.makeSyncedStore()
        let elsewhere = harness.directory.url.appending(path: "Elsewhere", directoryHint: .isDirectory)

        store.setDownloadDirectory(elsewhere)
        #expect(try singleFileTarget(in: store).localURL.path.hasPrefix(elsewhere.path))
        #expect(harness.makeStore().downloadDirectory.path == elsewhere.path)

        store.resetDownloadDirectory()
        #expect(store.downloadDirectory == harness.environment.defaultDownloadDirectory)
    }
}

@MainActor
@Suite struct LibraryStoreTagTests {
    private let harness = StoreHarness()
    private let tagger = FinderTagger()

    private func downloadedTarget(in store: LibraryStore) async throws -> DownloadTarget {
        let item = try #require(store.item(id: "PZO1E"))
        let target = store.locator.target(for: item.editions[0], in: item)
        store.download(target)
        await store.waitForDownloads()
        return target
    }

    @Test func tagsAreStoredAndSurviveARelaunch() async {
        let store = await harness.makeSyncedStore()

        store.addTag(" Played ", to: "PZO1E")
        store.addTag("Played", to: "PZO1E")
        store.addTag("", to: "PZO1E")
        store.addTag("GM Prep", to: "PZO1E")
        store.addTag("Ignored", to: "unknown")
        store.removeTag("Missing", from: "PZO1E")
        await store.waitUntilIdle()

        #expect(store.item(id: "PZO1E")?.tags == ["Played", "GM Prep"])
        #expect(store.allTags == ["GM Prep", "Played"])
        #expect(await harness.makeSyncedStore().item(id: "PZO1E")?.tags == ["Played", "GM Prep"])
    }

    @Test func tagChangesAreWrittenToDownloadedFiles() async throws {
        let store = await harness.makeSyncedStore()
        let target = try await downloadedTarget(in: store)

        store.addTag("Played", to: "PZO1E")
        #expect(tagger.tags(of: target.localURL) == ["Played"])

        store.removeTag("Played", from: "PZO1E")
        #expect(tagger.tags(of: target.localURL).isEmpty)
        #expect(store.item(id: "PZO1E")?.tags.isEmpty == true)
    }

    @Test func newDownloadsReceiveTheTitlesTags() async throws {
        let store = await harness.makeSyncedStore()
        store.addTag("Campaign", to: "PZO1E")

        let target = try await downloadedTarget(in: store)

        #expect(tagger.tags(of: target.localURL) == ["Campaign"])
    }

    @Test func tagsAddedInFinderArePickedUpAtLaunch() async throws {
        let store = await harness.makeSyncedStore()
        let target = try await downloadedTarget(in: store)
        try tagger.setTags(["From Finder"], on: target.localURL)

        let relaunched = await harness.makeSyncedStore()

        #expect(relaunched.item(id: "PZO1E")?.tags == ["From Finder"])
        #expect(relaunched.query.filter(relaunched.items, downloadedIDs: []).count == 2)
    }
}
