import Foundation
@testable import ScrollkeeperKit
import Testing

@MainActor
@Suite struct DemoModeTests {
    private func makeStore() async -> LibraryStore {
        let store = LibraryStore(environment: .demo(downloadDuration: 0.04))
        await store.start()
        await store.waitUntilIdle()
        return store
    }

    @Test func demoLibraryLoadsSignedInWithVariedTitles() async throws {
        let store = await makeStore()

        #expect(store.account == .signedIn(email: "demo@example.com"))
        #expect(store.items.count == DemoCatalog.titles.count)
        #expect(store.sync.failure.isEmpty)
        let lines = Set(store.items.map(\.classification.productLine))
        let expected: Set<ProductLine> = [
            .rulebook, .adventurePath, .adventure, .societyScenario, .bounty, .maps, .fiction
        ]
        #expect(lines.isSuperset(of: expected))
        let systems = Set(store.items.map(\.classification.gameSystem))
        #expect(systems.isSuperset(of: [.pathfinder2, .starfinder2]))

        let volume = try #require(store.item(id: "DEMO3002E"))
        #expect(volume.classification.series == "Demo Road")
        #expect(volume.classification.levelRange == 5...7)
        #expect(volume.author == "Blake Example")
        #expect(volume.pageCount == 96)
        #expect(try #require(store.item(id: "DEMO1001E")).editions.count == 2)
    }

    @Test func demoDownloadTakesItsTimeAndProducesAFile() async throws {
        let store = await makeStore()
        let item = try #require(store.item(id: "DEMO1003E"))
        let target = try #require(store.quickActions(for: item).download)

        store.download(target)
        #expect(store.pendingDownloadCount == 1)
        await store.waitForDownloads()

        #expect(store.isDownloaded(target))
        #expect(try String(contentsOf: target.localURL, encoding: .utf8).hasPrefix("%PDF-1.4"))
    }

    @Test func demoDownloadCanBeCanceled() async throws {
        let store = LibraryStore(environment: .demo(downloadDuration: 30))
        await store.start()
        await store.waitUntilIdle()
        let item = try #require(store.item(id: "DEMO1003E"))
        let target = try #require(store.quickActions(for: item).download)

        store.download(target)
        store.cancelDownload(target)
        await store.waitForDownloads()

        #expect(!store.isDownloaded(target))
        #expect(store.downloadJobs.isEmpty)
    }

    @Test func demoModeIsChosenByALaunchArgument() {
        let demo = LibraryEnvironment.forLaunch(arguments: ["Scrollkeeper", LibraryEnvironment.demoArgument])
        #expect(demo.credentials.load()?.email == "demo@example.com")
        #expect(demo.dataDirectory.lastPathComponent.hasPrefix("ScrollkeeperDemo-"))

        let live = LibraryEnvironment.forLaunch(arguments: ["Scrollkeeper"])
        #expect(live.dataDirectory.lastPathComponent == "Scrollkeeper")
    }

    @Test func demoServerAnswersUnknownAddressesWithNotFound() async throws {
        let client = DemoHTTPClient()
        let unknown = try #require(URL(string: "https://store.paizo.com/nowhere"))
        #expect(try await client.send(URLRequest(url: unknown)).statusCode == 404)
        #expect(DemoCatalog.product(sku: "NOT-IN-DEMO") == nil)
    }

    @Test func inMemoryCredentialsCanBeSavedAndDeleted() throws {
        let store = InMemoryCredentialStore()
        #expect(store.load() == nil)
        try store.save(Credentials(email: "a@example.com", password: "x"))
        #expect(store.load()?.email == "a@example.com")
        try store.delete()
        #expect(store.load() == nil)
    }
}
