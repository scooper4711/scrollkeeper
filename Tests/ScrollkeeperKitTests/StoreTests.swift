import Foundation
@testable import ScrollkeeperKit
import Testing

@MainActor
@Suite struct LibraryStoreSyncTests {
    private let harness = StoreHarness()

    @Test func firstLaunchWithAccountSyncsCatalogArtworkAndSummaries() async throws {
        let store = await harness.makeSyncedStore()

        #expect(store.account == .signedIn(email: "gamer@example.com"))
        #expect(store.items.map(\.title) == ["Pathfinder Adventure", "Pathfinder Flip-Mat: Carnival"])
        #expect(store.sync == SyncProgress(isRunning: false, fetched: 3, total: 3, failure: ""))
        #expect(store.sync.fraction == 1)
        #expect(!store.artwork.isRunning)

        let adventure = try #require(store.item(id: "PZO1E"))
        #expect(adventure.editions.map(\.label) == ["Single File", "File per Chapter"])
        #expect(adventure.metadata.pageCount == 64)
        #expect(adventure.classification.levelRange == 3...5)
        #expect(store.coverURL(for: adventure) != nil)
        #expect(store.coverURL(for: try #require(store.item(id: "PZO2E"))) == nil)
        #expect(try #require(store.item(id: "PZO2E")).metadata.isEmpty)
        #expect(store.facets.total == 2)
    }

    @Test func catalogIsLoadedFromDiskWithoutContactingPaizo() async {
        _ = await harness.makeSyncedStore()
        let requestsBefore = harness.paizo.http.requests.count

        let relaunched = await harness.makeSyncedStore()

        #expect(relaunched.items.count == 2)
        #expect(relaunched.item(id: "PZO1E")?.metadata.name == "Pathfinder Adventure PDF")
        #expect(harness.paizo.http.requests.count == requestsBefore)
    }

    @Test func metadataFromAnOlderVersionIsFetchedAgainButCoversAreKept() async {
        _ = await harness.makeSyncedStore()
        let lookups = harness.paizo.http.count(of: "POST https://store.paizo.com/graphql")
        harness.environment.settings.metadataVersion = ProductMetadata.schemaVersion - 1

        let relaunched = await harness.makeSyncedStore()

        #expect(harness.paizo.http.count(of: "POST https://store.paizo.com/graphql") == lookups + 1)
        #expect(harness.paizo.http.count(of: "https://cdn.example/PZO1E.jpg") == 1)
        #expect(relaunched.item(id: "PZO1E")?.metadata.pageCount == 64)
        #expect(harness.environment.settings.metadataVersion == ProductMetadata.schemaVersion)
    }

    @Test func withoutAccountNothingIsFetched() async {
        let signedOut = StoreHarness(account: nil)
        let store = await signedOut.makeSyncedStore()

        #expect(store.account == .signedOut)
        #expect(store.items.isEmpty)
        #expect(signedOut.paizo.http.requests.isEmpty)
        #expect(store.storedEmail.isEmpty)
        #expect(store.item(id: nil) == nil)
    }

    @Test func refreshAddsOnlyNewEntitlements() async {
        let store = await harness.makeSyncedStore()
        let newest = Fixtures.record(id: "new", name: "Pathfinder Bounty #1: The Whitefang Wyrm", sku: "PZO3E")
        harness.paizo.installLibrary(records: [newest] + StoreHarness.records)

        store.startRefresh()
        await store.waitUntilIdle()

        #expect(store.items.count == 3)
        #expect(store.item(id: "PZO3E")?.classification.productLine == .bounty)
        #expect(store.sync.fetched == 4)
        #expect(store.sync.failure.isEmpty)
    }

    @Test func fullSyncDropsEntitlementsPaizoNoLongerLists() async {
        let store = await harness.makeSyncedStore()
        harness.paizo.installLibrary(records: Array(StoreHarness.records.prefix(2)))

        store.startFullSync()
        await store.waitUntilIdle()

        #expect(store.items.map(\.id) == ["PZO1E"])
    }

    @Test func failedSyncReportsWhyAndKeepsWhatItHas() async {
        let store = await harness.makeSyncedStore()
        harness.paizo.http.on("https://app.paizo.com/customer-library", text: "", status: 502)

        store.startFullSync()
        store.startFullSync()
        await store.waitUntilIdle()

        #expect(store.sync.failure == "Loading library page 1 failed: Paizo answered with status 502.")
        #expect(!store.sync.isRunning)
        #expect(store.items.count == 2)
    }

    @Test func interruptedFirstSyncIsStartedAgainAtNextLaunch() async {
        let repaired = Flag()
        let secondPage = Fixtures.libraryPageHTML(records: [StoreHarness.records[2]], count: 3)
        harness.paizo.http.on("customer-library?token=\(FakePaizo.token)&page=2") { request in
            let status = repaired.isSet ? 200 : 500
            return HTTPResponse(data: Data(secondPage.utf8), statusCode: status, finalURL: request.url)
        }
        let interrupted = await harness.makeSyncedStore()
        #expect(interrupted.items.count == 1)
        #expect(!interrupted.sync.failure.isEmpty)
        #expect(!harness.environment.settings.hasCompletedFullSync)

        repaired.set()
        let relaunched = await harness.makeSyncedStore()

        #expect(relaunched.items.count == 2)
        #expect(relaunched.sync.failure.isEmpty)
        #expect(harness.environment.settings.hasCompletedFullSync)
    }

    @Test func canceledSyncEndsQuietly() async {
        let store = await harness.makeSyncedStore()
        store.startFullSync()
        store.cancelSync()
        await store.waitUntilIdle()

        #expect(!store.sync.isRunning)
        #expect(store.sync.failure.isEmpty)
    }

    @Test func queryAndSortOrderDecideWhatIsVisible() async {
        let store = await harness.makeSyncedStore()
        #expect(store.visibleItems.map(\.id) == ["PZO1E", "PZO2E"])

        store.sortOrder = [KeyPathComparator(\LibraryTitle.titleSortKey, order: .reverse)]
        #expect(store.visibleItems.map(\.id) == ["PZO2E", "PZO1E"])

        store.query.searchText = "carnival"
        #expect(store.visibleItems.map(\.id) == ["PZO2E"])
    }

    @Test func unreachableStorefrontLeavesTitlesWithoutMetadata() async {
        harness.paizo.http.on("POST https://store.paizo.com/graphql", text: "", status: 500)
        let store = await harness.makeSyncedStore()

        #expect(store.items.count == 2)
        #expect(store.item(id: "PZO1E")?.metadata.isEmpty == true)
        #expect(store.artwork == ArtworkProgress())
    }
}

@MainActor
@Suite struct LibraryStoreAccountTests {
    private let harness = StoreHarness(account: nil)

    @Test func signInStoresTheAccountAndStartsTheFirstSync() async {
        let store = harness.makeStore()
        await store.start()

        await store.signIn(email: " gamer@example.com ", password: FakePaizo.account.password)
        await store.waitUntilIdle()

        #expect(store.account == .signedIn(email: "gamer@example.com"))
        #expect(harness.credentials.load() == FakePaizo.account)
        #expect(store.storedEmail == "gamer@example.com")
        #expect(store.items.count == 2)
    }

    @Test func rejectedSignInExplainsAndStoresNothing() async {
        let store = harness.makeStore()
        await store.signIn(email: "gamer@example.com", password: "wrong")

        #expect(store.account == .failed(message: "Signing in failed: Paizo did not accept the email and password."))
        #expect(harness.credentials.load() == nil)
    }

    @Test func incompleteAccountIsNotSent() async {
        let store = harness.makeStore()
        await store.signIn(email: "", password: "x")

        #expect(store.account == .failed(
            message: "Enter both the email address and the password of your Paizo account."
        ))
        #expect(harness.paizo.http.requests.isEmpty)
    }

    @Test func signOutForgetsTheAccountButKeepsTheCatalog() async {
        let signedIn = StoreHarness()
        let store = await signedIn.makeSyncedStore()

        store.signOut()

        #expect(store.account == .signedOut)
        #expect(signedIn.credentials.load() == nil)
        #expect(store.items.count == 2)
    }
}
