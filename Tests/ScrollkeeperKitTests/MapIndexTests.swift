import Foundation
@testable import ScrollkeeperKit
import Testing

@MainActor
@Suite struct MapIndexTests {
    private static let records: [[String: Any]] = [
        Fixtures.record(id: "forest", name: "Pathfinder Flip-Mat Classics: Forest PDF", sku: "MAP1"),
        Fixtures.record(id: "forest-jpg", name: "Pathfinder Flip-Mat Classics: Forest JPGs", sku: "MAP1",
                        file: "forest.zip"),
        Fixtures.record(id: "tiles", name: "Pathfinder Flip-Tiles: Dungeon Starter Set JPGs", sku: "MAP2",
                        file: "tiles.zip"),
        Fixtures.record(id: "poster", name: "Pathfinder Poster Map Folio PDF", sku: "MAP3"),
        Fixtures.record(id: "core", name: "Core Rules PDF", sku: "CORE")
    ]

    private let harness = StoreHarness(records: MapIndexTests.records)

    private func readIndex() throws -> MapIndex {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MapIndex.self, from: Data(contentsOf: harness.environment.mapIndexURL))
    }

    @Test func listsMapsThatCanBeFetchedWithOneClickInTitleOrder() async throws {
        _ = await harness.makeSyncedStore()

        let index = try readIndex()

        #expect(index.formatVersion == MapIndex.currentFormatVersion)
        #expect(index.generatedAt == harness.clock.now)
        #expect(index.titles.map(\.sku) == ["MAP1", "MAP3"])
        #expect(index.titles.allSatisfy { !$0.title.isEmpty })
    }

    @Test func writesNothingBeforeACatalogExists() async {
        let empty = StoreHarness(account: nil, records: [])
        let store = empty.makeStore()
        await store.start()
        await store.waitUntilIdle()

        #expect(!FileManager.default.fileExists(atPath: empty.environment.mapIndexURL.path))
    }

    @Test func isRewrittenOnlyWhenTheEntriesChange() async throws {
        let store = await harness.makeSyncedStore()
        let url = harness.environment.mapIndexURL
        try FileManager.default.removeItem(at: url)

        store.rebuildItems()
        await store.waitUntilIdle()

        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func entriesCarrySeriesAndNumberWhenClassified() {
        var item = LibraryTitle(id: "M", sku: "M", title: "Flip-Mat #4", editions: [
            Edition(entitlement: Fixtures.entitlement("Flip-Mat #4 PDF", sku: "M"), kind: .singleFile, label: "")
        ])
        item.classification.productLine = .maps
        item.classification.series = "Flip-Mat"
        item.classification.number = 4

        let entries = MapIndex.entries(from: [item])

        #expect(entries == [MapIndex.Entry(sku: "M", title: "Flip-Mat #4", series: "Flip-Mat", number: 4)])
    }

    @Test func encodesDatesAsISO8601() throws {
        let index = MapIndex(generatedAt: Date(timeIntervalSince1970: 0), titles: [])
        let text = try #require(String(bytes: try index.encoded(), encoding: .utf8))
        #expect(text.contains("\"generatedAt\" : \"1970-01-01T00:00:00Z\""))
        #expect(text.contains("\"formatVersion\" : 1"))
    }
}
