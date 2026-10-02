import Foundation
@testable import ScrollkeeperKit
import Testing

@MainActor
@Suite struct StoreUpdateCheckTests {
    private let harness = StoreHarness()
    private let day = UpdateCheckPolicy.day
    private let lookup = "/api/library/entitlement/customer/"
    /// Later than any file these tests create.
    private let updated = "Wed Sep 02 2099 20:52:57 GMT+0000 (Coordinated Universal Time)"

    /// A synced store with the single-file edition of the adventure downloaded.
    private func makeStoreWithDownload() async throws -> LibraryStore {
        let store = await harness.makeSyncedStore()
        let item = try #require(store.item(id: "PZO1E"))
        store.download(try singleFileTarget(of: item, in: store))
        await store.waitForDownloads()
        return store
    }

    private func singleFileTarget(of item: LibraryTitle, in store: LibraryStore) throws -> DownloadTarget {
        let edition = try #require(item.editions.first { $0.id == "ap-single" })
        return store.locator.target(for: edition, in: item)
    }

    private func relaunch() async -> LibraryStore {
        let store = harness.makeStore()
        await store.start()
        await store.waitUntilIdle()
        return store
    }

    @Test func openingATitleFindsThatItsDownloadWasUpdated() async throws {
        harness.paizo.installFileStatus(updated: ["ap-single": updated, "ap-chapters": updated])
        let store = try await makeStoreWithDownload()
        #expect(store.outdatedItemIDs.isEmpty)

        harness.clock.advance(by: 2 * day)
        store.checkForFileUpdates(of: try #require(store.item(id: "PZO1E")))
        await store.waitUntilIdle()

        let target = try singleFileTarget(of: try #require(store.item(id: "PZO1E")), in: store)
        #expect(store.isOutdated(target))
        #expect(store.outdatedItemIDs == ["PZO1E"])
        #expect(target.remote.fileName == "book-v2.pdf")
        #expect(store.lastUpdateCheck == harness.clock.now)
        // Only the downloaded edition was asked about.
        #expect(harness.paizo.http.count(of: lookup) == 1)
        #expect(harness.paizo.http.count(of: lookup + "ap-single") == 1)
    }

    @Test func aTitleIsNotCheckedTwiceInADay() async throws {
        harness.paizo.installFileStatus(updated: ["ap-single": ""])
        let store = try await makeStoreWithDownload()
        let item = try #require(store.item(id: "PZO1E"))

        // The sync that has just finished counts as a check.
        store.checkForFileUpdates(of: item)
        await store.waitUntilIdle()
        #expect(harness.paizo.http.count(of: lookup) == 0)

        harness.clock.advance(by: day)
        store.checkForFileUpdates(of: item)
        store.checkForFileUpdates(of: item)
        await store.waitUntilIdle()
        #expect(harness.paizo.http.count(of: lookup) == 1)

        harness.clock.advance(by: day)
        store.checkForFileUpdates(of: item)
        await store.waitUntilIdle()
        #expect(harness.paizo.http.count(of: lookup) == 2)
    }

    @Test func downloadsAreCheckedWhenTheAppOpensAndTheCheckIsRemembered() async throws {
        harness.paizo.installFileStatus(updated: ["ap-single": updated])
        _ = try await makeStoreWithDownload()
        harness.clock.advance(by: 2 * day)

        let relaunched = await relaunch()
        #expect(harness.paizo.http.count(of: lookup) == 1)
        #expect(relaunched.outdatedItemIDs == ["PZO1E"])

        let again = await relaunch()
        #expect(harness.paizo.http.count(of: lookup) == 1)
        #expect(again.lastUpdateCheck == harness.clock.now)
        #expect(again.outdatedItemIDs == ["PZO1E"])
    }

    @Test func downloadsAreCheckedAfterARefresh() async throws {
        harness.paizo.installFileStatus(updated: ["ap-single": updated])
        let store = try await makeStoreWithDownload()
        harness.clock.advance(by: 2 * day)

        store.startRefresh()
        await store.waitUntilIdle()

        #expect(harness.paizo.http.count(of: lookup) == 1)
        #expect(store.outdatedItemIDs == ["PZO1E"])
    }

    @Test func aFailedCheckSaysNothingAndIsTriedAgain() async throws {
        let store = try await makeStoreWithDownload()
        let listed = store.lastUpdateCheck
        harness.clock.advance(by: 2 * day)

        store.checkForFileUpdates()
        await store.waitUntilIdle()
        #expect(store.sync.failure.isEmpty)
        #expect(store.lastUpdateCheck == listed)
        // One request and one retry with a renewed token.
        #expect(harness.paizo.http.count(of: lookup) == 2)

        harness.paizo.installFileStatus(updated: ["ap-single": updated])
        store.checkForFileUpdates()
        await store.waitUntilIdle()
        #expect(store.outdatedItemIDs == ["PZO1E"])
    }

    @Test func nothingIsCheckedWithoutAnAccount() async {
        let signedOut = StoreHarness(account: nil)
        let store = signedOut.makeStore()
        await store.start()

        store.checkForFileUpdates()
        store.checkForFileUpdates(of: LibraryTitle(id: "PZO1E", sku: "PZO1E", title: "Adventure", editions: []))
        await store.waitUntilIdle()

        #expect(signedOut.paizo.http.requests.isEmpty)
        #expect(store.lastUpdateCheck == nil)
    }

    @Test func aLibraryDownloadedInFullIsListedAgainInsteadOfLookedUp() async throws {
        harness.updateCheckPolicy.listingThreshold = 0
        harness.paizo.installFileStatus(updated: ["ap-single": updated])
        _ = try await makeStoreWithDownload()
        let pages = harness.paizo.http.count(of: "customer-library")

        // Within the month nothing happens.
        harness.clock.advance(by: 10 * day)
        _ = await relaunch()
        #expect(harness.paizo.http.count(of: "customer-library") == pages)

        // After it the library is listed once, and no edition is looked up singly.
        harness.clock.advance(by: 21 * day)
        let relaunched = await relaunch()
        #expect(harness.paizo.http.count(of: "customer-library") == pages + 2)
        #expect(relaunched.lastUpdateCheck == harness.clock.now)
        _ = await relaunch()
        #expect(harness.paizo.http.count(of: "customer-library") == pages + 2)
        #expect(harness.paizo.http.count(of: lookup) == 0)
    }

    @Test func aFullSyncCanAskForFewerPagesAtOnce() async throws {
        let paizo = FakePaizo()
        paizo.installSignedInStore()
        let records = (1...7).map { Fixtures.record(id: "pkg-\($0)", name: "Book \($0) PDF") }
        paizo.installLibrary(records: records)
        let session = PaizoSession(http: paizo.http, credentials: MemoryCredentialStore(FakePaizo.account))
        let client = LibraryCatalogClient(http: paizo.http, session: session)
        let fetched = Counter()

        try await CatalogSynchronizer(client: client, pagesAtOnce: 1).fetchAll { page in
            page.entitlements.forEach { _ in fetched.increment() }
        }

        #expect(fetched.current == 7)
    }

    @Test func theDemoLibraryAnswersLookups() async throws {
        let url = try #require(URL(string: "https://app.paizo.com/api/library/entitlement/customer/demo-DEMO1003E-0"))
        let answer = try await DemoHTTPClient().send(URLRequest(url: url))
        #expect(answer.text.contains(#""File":"book.pdf""#))
    }
}
