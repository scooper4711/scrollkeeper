import Foundation
@testable import ScrollkeeperKit
import Testing

@MainActor
@Suite struct QuickActionTests {
    private static let updated = "Wed Sep 02 2020 20:52:57 GMT+0000 (Coordinated Universal Time)"
    private static let records: [[String: Any]] = [
        Fixtures.record(id: "core-chapters", name: "Core Rules PDF - File per Chapter", sku: "CORE", file: "c.zip"),
        Fixtures.record(Fixtures.RecordFields(
            id: "core-single", name: "Core Rules PDF - Single File", sku: "CORE", file: "core.pdf", updated: updated
        )),
        Fixtures.record(id: "novel-epub", name: "Nightglass ePub", sku: "NOVEL", file: "n.epub"),
        Fixtures.record(id: "novel-pdf", name: "Nightglass PDF", sku: "NOVEL", file: "n.pdf"),
        Fixtures.record(id: "runes", name: "Community Use Package: Runes", sku: "RUNES", file: "runes.zip"),
        Fixtures.record(id: "ghost", name: "Unreleased Scenario", sku: "GHOST", file: "")
    ]

    private let harness = StoreHarness(records: QuickActionTests.records)

    private func makeStore() async -> LibraryStore {
        await harness.makeSyncedStore()
    }

    @Test func offersTheSingleFileBeforeTheChapters() async throws {
        let store = await makeStore()
        let actions = store.quickActions(for: try #require(store.item(id: "CORE")))

        #expect(actions.open == nil)
        #expect(actions.download?.remote.displayName == "Core Rules PDF - Single File")
        #expect(!actions.isUpdate)
    }

    @Test func offersThePDFBeforeTheEPub() async throws {
        let store = await makeStore()
        let actions = store.quickActions(for: try #require(store.item(id: "NOVEL")))
        #expect(actions.download?.remote.displayName == "Nightglass PDF")
    }

    @Test func offersNothingForAssetPacksAndFilesPaizoHasNotAttached() async throws {
        let store = await makeStore()
        #expect(store.quickActions(for: try #require(store.item(id: "RUNES"))) == TitleActions())
        #expect(store.quickActions(for: try #require(store.item(id: "GHOST"))) == TitleActions())
    }

    @Test func downloadedTitleOffersOpenAndNoDownload() async throws {
        let store = await makeStore()
        let item = try #require(store.item(id: "CORE"))
        let target = try #require(store.quickActions(for: item).download)

        store.download(target)
        await store.waitForDownloads()

        let actions = store.quickActions(for: item)
        #expect(actions.open == target)
        #expect(actions.download == nil)
        #expect(store.openableURL(for: target) == target.localURL)
    }

    @Test func outdatedCopyOffersBothOpenAndUpdate() async throws {
        let store = await makeStore()
        let item = try #require(store.item(id: "CORE"))
        let target = try #require(store.quickActions(for: item).download)
        store.download(target)
        await store.waitForDownloads()
        let earlier = Date(timeIntervalSince1970: 1_500_000_000)
        try FileManager.default.setAttributes([.creationDate: earlier], ofItemAtPath: target.localURL.path)

        let actions = store.quickActions(for: item)

        #expect(actions.open == target)
        #expect(actions.download == target)
        #expect(actions.isUpdate)
    }

    @Test func aLessCommonEditionOnDiskIsTheOneToOpen() async throws {
        let store = await makeStore()
        let item = try #require(store.item(id: "NOVEL"))
        let epub = try #require(item.editions.first { $0.kind == .epub })
        let target = store.locator.target(for: epub, in: item)
        store.download(target)
        await store.waitForDownloads()

        let actions = store.quickActions(for: item)

        #expect(actions.open == target)
        #expect(actions.download == nil)
    }

    @Test func unpackedArchiveOpensItsFolderUnlessItHoldsOneFile() async throws {
        let store = await makeStore()
        let item = try #require(store.item(id: "CORE"))
        let chapters = try #require(item.editions.first { $0.kind == .filePerChapter })
        let target = store.locator.target(for: chapters, in: item)

        harness.paizo.http.on("https://s3.example/signed", data: try Fixtures.zipArchive(files: ["only.pdf": "x"]))
        store.download(target)
        await store.waitForDownloads()
        #expect(store.openableURL(for: target).lastPathComponent == "only.pdf")

        let two = try Fixtures.zipArchive(files: ["01.pdf": "x", "02.pdf": "y"])
        harness.paizo.http.on("https://s3.example/signed", data: two)
        store.download(target)
        await store.waitForDownloads()
        #expect(store.openableURL(for: target) == target.localURL)
    }
}

@MainActor
@Suite struct DownloadQueueTests {
    private static let records = (1...7).map { Fixtures.record(id: "p\($0)", name: "Book \($0) PDF", sku: "SKU\($0)") }
    private let harness = StoreHarness(records: DownloadQueueTests.records)

    private func targets(in store: LibraryStore) -> [DownloadTarget] {
        store.items.map { store.locator.target(for: $0.editions[0], in: $0) }
    }

    @Test func runsFiveAtATimeAndTheRestWaitTheirTurn() async {
        let store = await harness.makeSyncedStore()
        let targets = targets(in: store)
        #expect(targets.count == 7)

        targets.forEach(store.download)

        let states = store.downloadJobs.map(\.state)
        #expect(states.filter { $0 == .inProgress(0) }.count == LibraryStore.maximumConcurrentDownloads)
        #expect(states.filter { $0 == .waiting }.count == 2)
        #expect(store.pendingDownloadCount == 7)
        #expect(store.downloadJobs.map(\.id) == targets.map(\.id))
        #expect(Set(store.downloadJobs.map(\.name)) == Set((1...7).map { "Book \($0) PDF" }))
        #expect(store.downloadJobs.allSatisfy { $0.state.isPending && $0.id == $0.target.id })

        await store.waitForDownloads()

        #expect(store.downloadJobs.isEmpty)
        #expect(store.pendingDownloadCount == 0)
        #expect(targets.allSatisfy(store.isDownloaded))
    }

    @Test func waitingDownloadCanBeCancelledBeforeItStarts() async {
        let store = await harness.makeSyncedStore()
        let targets = targets(in: store)
        targets.forEach(store.download)

        store.cancelDownload(targets[6])
        #expect(store.downloads[targets[6].id] == nil)
        #expect(store.downloadJobs.count == 6)
        await store.waitForDownloads()

        #expect(!store.isDownloaded(targets[6]))
        #expect(targets.prefix(6).allSatisfy(store.isDownloaded))
    }

    @Test func cancelAllStopsRunningAndWaitingDownloads() async {
        let store = await harness.makeSyncedStore()
        let targets = targets(in: store)
        targets.forEach(store.download)

        store.cancelAllDownloads()
        await store.waitForDownloads()

        #expect(store.downloadJobs.isEmpty)
        #expect(!store.isDownloaded(targets[6]))
        #expect(!store.isDownloaded(targets[5]))
    }

    @Test func interruptedDownloadResumesWhenTheAppComesBack() async {
        let store = await harness.makeSyncedStore()
        let target = targets(in: store)[0]
        harness.paizo.http.on("https://s3.example/signed") { _ in throw URLError(.networkConnectionLost) }

        store.download(target)
        await store.waitForDownloads()
        #expect(store.downloads[target.id] == .interrupted)
        #expect(store.pendingDownloadCount == 0)
        #expect(!DownloadState.interrupted.isPending)

        harness.paizo.installDownloads()
        store.resumeInterruptedDownloads()
        #expect(store.pendingDownloadCount == 1)
        await store.waitForDownloads()

        #expect(store.downloadJobs.isEmpty)
        #expect(store.isDownloaded(target))
    }

    @Test func refusedDownloadIsNotResumedByItself() async {
        let store = await harness.makeSyncedStore()
        let target = targets(in: store)[0]
        harness.paizo.http.on("https://s3.example/signed", text: "denied", status: 403)
        store.download(target)
        await store.waitForDownloads()

        store.resumeInterruptedDownloads()

        #expect(store.pendingDownloadCount == 0)
        #expect(store.downloadJobs.count == 1)
    }

    @Test(arguments: [URLError.Code.networkConnectionLost, .notConnectedToInternet, .timedOut])
    func droppedConnectionsCountAsInterruptions(code: URLError.Code) {
        #expect(LibraryStore.isInterruption(URLError(code)))
    }

    @Test func otherErrorsAreNotInterruptions() {
        #expect(!LibraryStore.isInterruption(URLError(.badServerResponse)))
        #expect(!LibraryStore.isInterruption(PaizoError.tokenExpired))
    }

    @Test func interruptedDownloadCanAlsoBeRetriedByHand() async {
        let store = await harness.makeSyncedStore()
        let target = targets(in: store)[0]
        harness.paizo.http.on("https://s3.example/signed") { _ in throw URLError(.timedOut) }
        store.download(target)
        await store.waitForDownloads()

        harness.paizo.installDownloads()
        store.retryDownload(target)
        await store.waitForDownloads()

        #expect(store.isDownloaded(target))
    }

    @Test func failedDownloadCanBeRetriedFromTheList() async {
        let store = await harness.makeSyncedStore()
        let target = targets(in: store)[0]
        store.retryDownload(target)
        #expect(store.downloadJobs.isEmpty)

        harness.paizo.http.on("https://s3.example/signed", text: "interrupted", status: 503)
        store.download(target)
        await store.waitForDownloads()
        #expect(store.downloadJobs.count == 1)

        harness.paizo.installDownloads()
        store.retryDownload(target)
        #expect(store.downloads[target.id] == .inProgress(0))
        store.retryDownload(target)
        await store.waitForDownloads()

        #expect(store.downloadJobs.isEmpty)
        #expect(store.isDownloaded(target))
    }

    @Test func failedDownloadStaysListedUntilDismissedOrRetried() async {
        let store = await harness.makeSyncedStore()
        let target = targets(in: store)[0]
        harness.paizo.http.on("https://s3.example/signed", text: "denied", status: 403)

        store.download(target)
        #expect(store.pendingDownloadCount == 1)
        await store.waitForDownloads()
        #expect(store.downloadJobs.map(\.state.isPending) == [false])
        #expect(store.pendingDownloadCount == 0)

        store.dismissDownload(target)
        #expect(store.downloadJobs.isEmpty)

        store.download(target)
        store.dismissDownload(target)
        #expect(store.downloadJobs.count == 1)
        await store.waitForDownloads()

        harness.paizo.installDownloads()
        store.download(target)
        await store.waitForDownloads()
        #expect(store.downloadJobs.isEmpty)
        #expect(store.isDownloaded(target))
    }
}
