import Foundation
@testable import ScrollkeeperKit
import Testing

@MainActor
@Suite struct BuiltInTitleTests {
    private let supplement = BuiltInTitles.webSupplement
    private let publicURL = "https://downloads.paizo.com/PZO13003_SupplementalGodTable.pdf"

    private func harness() -> StoreHarness {
        let harness = StoreHarness()
        harness.builtInTitles = BuiltInTitles.all
        harness.paizo.http.on(publicURL, text: "%PDF-supplement")
        harness.paizo.http.on(BuiltInTitles.godsAndMagicSupplement.entitlement.filePath, text: "%PDF-intercessions")
        return harness
    }

    private func supplementTarget(in store: LibraryStore) throws -> DownloadTarget {
        let item = try #require(store.item(id: BuiltInTitles.webSupplementSKU))
        return store.locator.target(for: item.editions[0], in: item)
    }

    @Test func joinsTheLibraryWithItsOwnMetadataButIsNeverStoredOrLookedUp() async throws {
        let harness = harness()
        let store = await harness.makeSyncedStore()
        let item = try #require(store.item(id: BuiltInTitles.webSupplementSKU))
        #expect(item.title == "Pathfinder Lost Omens Divine Mysteries Web Supplement")
        #expect(item.metadata.brand == "Pathfinder 2E Remaster")
        #expect(store.items.count == 4)
        #expect(store.item(id: BuiltInTitles.godsAndMagicSupplementSKU)?.title
                == "Pathfinder Lost Omens Gods & Magic Web Supplement")
        #expect(!store.snapshot.entitlements.contains(where: BuiltInTitles.contains))
        #expect(harness.paizo.http.count(of: BuiltInTitles.webSupplementSKU) == 0)
    }

    @Test func staysOutOfALibraryNotReadYet() async {
        let store = harness().makeStore()
        #expect(store.items.isEmpty)
        #expect(CatalogSnapshot().adding(BuiltInTitles.all).entitlements.isEmpty)
    }

    @Test func survivesAFullSync() async throws {
        let harness = harness()
        let store = await harness.makeSyncedStore()
        store.startFullSync()
        await store.waitUntilIdle()
        #expect(store.item(id: BuiltInTitles.webSupplementSKU) != nil)
    }

    @Test func downloadsFromItsPublicAddressWithoutAskingPaizo() async throws {
        let harness = harness()
        let store = await harness.makeSyncedStore()
        let target = try supplementTarget(in: store)
        #expect(target.remote.isPublic)

        store.download(target)
        await store.waitForDownloads()

        #expect(try String(contentsOf: target.localURL, encoding: .utf8) == "%PDF-supplement")
        #expect(target.localURL.lastPathComponent == "Pathfinder Lost Omens Divine Mysteries Web Supplement.pdf")
        #expect(harness.paizo.http.count(of: "/api/library/download") == 0)
    }

    @Test func isLeftOutOfUpdateChecks() async throws {
        let harness = harness()
        harness.paizo.installFileStatus(updated: [:])
        let store = await harness.makeSyncedStore()
        store.download(try supplementTarget(in: store))
        await store.waitForDownloads()

        harness.clock.advance(by: 40 * UpdateCheckPolicy.day)
        store.checkForFileUpdates(of: try #require(store.item(id: BuiltInTitles.webSupplementSKU)))
        await store.waitUntilIdle()

        #expect(harness.paizo.http.count(of: "/api/library/entitlement/customer/builtin-") == 0)
    }

    @Test func fieldGuideCanAskForTitles() throws {
        let url = try #require(URL(string: "scrollkeeper://open?sku=PZO13003WS&app=fieldguide"))
        #expect(try HandoffRequest(url: url) == HandoffRequest(sku: "PZO13003WS", app: .fieldguide))
        #expect(HandoffApp.fieldguide.name == "Field Guide")
        #expect(HandoffApp.fieldguide.bundleIdentifier == "io.github.scooper4711.FieldGuide")
        #expect(HandoffApp.fieldguide.statusScheme == "fieldguide")
        #expect(HandoffApp.fieldguide.accepts(URL(filePath: "/a/book.pdf")))
        #expect(!HandoffApp.fieldguide.accepts(URL(filePath: "/a/map.jpg")))
    }
}
