import Foundation
@testable import ScrollkeeperKit
import Testing

/// The list of titles handed to an app that asks for it (`scrollkeeper://index`).
@MainActor
@Suite struct TitleIndexTests {
    private let harness = StoreHarness(records: [
        Fixtures.record(id: "pdf", name: "Pathfinder Adventure: Cradle PDF", sku: "CRADLE", file: "cradle.pdf"),
        Fixtures.record(id: "chapters", name: "Core Rules PDF - File per Chapter", sku: "CORE", file: "c.zip"),
        Fixtures.record(id: "epub", name: "Nightglass ePub", sku: "NOVEL", file: "n.epub"),
        Fixtures.record(id: "runes", name: "Community Use Package: Runes", sku: "RUNES", file: "runes.zip"),
        Fixtures.record(id: "ghost", name: "Unreleased Scenario", sku: "GHOST", file: "")
    ])

    @Test func listsTheTitlesWithAPDFOrAZipOfDocuments() async throws {
        let store = await harness.makeSyncedStore()
        let url = try await store.handoffIndex(for: .pluck)

        #expect(url.lastPathComponent == "pluck.scrollkeeperindex")
        let index = try Self.decode(url)
        #expect(index.formatVersion == TitleIndex.currentFormatVersion)
        #expect(index.titles.map(\.sku) == ["CORE", "CRADLE"])
        #expect(index.titles.allSatisfy { !$0.downloaded })
        #expect(index.titles.first { $0.sku == "CRADLE" }?.kind == ProductLine.adventure.label)
    }

    @Test func marksTitlesAlreadyDownloaded() async throws {
        let store = await harness.makeSyncedStore()
        let item = try #require(store.item(id: "CRADLE"))
        store.download(try #require(store.quickActions(for: item).download))
        await store.waitForDownloads()

        let index = try Self.decode(try await store.handoffIndex(for: .pluck))
        #expect(index.titles.first { $0.sku == "CRADLE" }?.downloaded == true)
    }

    @Test func listsOnlyMapsForMapsmith() async throws {
        let store = await StoreHarness(records: [
            Fixtures.record(id: "forest", name: "Pathfinder Flip-Mat Classics: Forest PDF", sku: "MAP1"),
            Fixtures.record(id: "core", name: "Core Rules PDF", sku: "CORE")
        ]).makeSyncedStore()

        let url = try await store.handoffIndex(for: .mapsmith)

        #expect(url.lastPathComponent == "mapsmith.scrollkeeperindex")
        let index = try Self.decode(url)
        #expect(index.titles.map(\.sku) == ["MAP1"])
        #expect(index.titles.first?.kind == ProductLine.maps.label)
    }

    @Test func refusesBeforeThereIsALibrary() async {
        let store = await StoreHarness(records: []).makeSyncedStore()
        await #expect(throws: HandoffError.noCatalog) { try await store.handoffIndex(for: .pluck) }
    }

    private static func decode(_ url: URL) throws -> TitleIndex {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TitleIndex.self, from: Data(contentsOf: url))
    }
}
