import Foundation
@testable import ScrollkeeperKit
import Testing

/// What Space previews for a title (6.6).
@MainActor
@Suite struct PreviewTests {
    private let harness = StoreHarness(records: [
        Fixtures.record(id: "core-chapters", name: "Core Rules PDF - File per Chapter", sku: "CORE", file: "c.zip"),
        Fixtures.record(id: "novel-pdf", name: "Nightglass PDF", sku: "NOVEL", file: "n.pdf")
    ])

    @Test func previewsTheDownloadedBookBeforeItsMaps() async throws {
        let store = await harness.makeSyncedStore()
        let item = try #require(store.item(id: "CORE"))
        let target = try #require(store.quickActions(for: item).download)
        let zip = try Fixtures.zipArchive(files: ["PZO90200 Interactive Maps.pdf": "x", "PZO90200E.pdf": "y"])
        harness.paizo.http.on("https://s3.example/signed", data: zip)
        store.download(target)
        await store.waitForDownloads()

        #expect(store.previewFiles(for: item).map(\.lastPathComponent) == [
            "PZO90200E.pdf", "PZO90200 Interactive Maps.pdf"
        ])
    }

    @Test func previewsTheCoverOfATitleNotDownloaded() async throws {
        let store = await harness.makeSyncedStore()
        let item = try #require(store.item(id: "NOVEL"))
        store.covers.store(Data("jpeg".utf8), sku: "NOVEL")

        #expect(store.previewFiles(for: item) == [store.covers.url(sku: "NOVEL")])
    }

    @Test func previewsNothingWithoutADownloadOrACover() async throws {
        let store = await harness.makeSyncedStore()
        let item = try #require(store.item(id: "NOVEL"))
        try? FileManager.default.removeItem(at: store.covers.url(sku: "NOVEL"))

        #expect(store.previewFiles(for: item).isEmpty)
    }
}
