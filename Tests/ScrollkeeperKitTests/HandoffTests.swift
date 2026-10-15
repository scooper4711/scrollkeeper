import Foundation
@testable import ScrollkeeperKit
import Testing

@Suite struct HandoffRequestTests {
    @Test func parsesTheSKUAndTheApp() throws {
        let url = try #require(URL(string: "scrollkeeper://open?sku=PZO31005&app=mapsmith"))
        let request = try HandoffRequest(url: url)
        #expect(request == HandoffRequest(sku: "PZO31005", app: .mapsmith))
    }

    @Test(arguments: [
        "https://open?sku=A&app=mapsmith",
        "scrollkeeper://delete?sku=A&app=mapsmith",
        "scrollkeeper:?sku=A&app=mapsmith",
        "scrollkeeper://open?app=mapsmith",
        "scrollkeeper://open?sku=&app=mapsmith"
    ])
    func refusesLinksItDoesNotRecognize(link: String) throws {
        let url = try #require(URL(string: link))
        #expect(throws: HandoffError.unrecognizedLink) { try HandoffRequest(url: url) }
    }

    @Test func parsesADownloadOnlyRequest() throws {
        let url = try #require(URL(string: "scrollkeeper://download?sku=PZO31005&app=mapsmith"))
        #expect(try HandoffRequest(url: url) == HandoffRequest(sku: "PZO31005", app: .mapsmith, action: .download))
    }

    @Test func refusesAppsNotOnTheList() throws {
        let url = try #require(URL(string: "scrollkeeper://open?sku=A&app=terminal"))
        #expect(throws: HandoffError.unknownApp("terminal")) { try HandoffRequest(url: url) }
    }

    @Test func mapsmithTakesPDFsAndImagesOnly() {
        let app = HandoffApp.mapsmith
        #expect(app.accepts(URL(filePath: "/maps/forest.pdf")))
        #expect(app.accepts(URL(filePath: "/maps/forest.JPG")))
        #expect(app.accepts(URL(filePath: "/maps/forest.png")))
        #expect(!app.accepts(URL(filePath: "/maps/readme.txt")))
        #expect(!app.accepts(URL(filePath: "/maps/noextension")))
        #expect(app.bundleIdentifier == "com.github.scooper4711.Mapsmith")
        #expect(app.name == "Mapsmith")
    }

    @Test(arguments: [
        HandoffError.unrecognizedLink, .unknownApp("x"), .signedOut, .titleNotFound(sku: "S"),
        .noEdition(title: "T"), .downloadFailed(title: "T", reason: "R"), .cancelled(title: "T"),
        .noAcceptedFiles(title: "T", app: "A"), .appNotInstalled(app: "A")
    ])
    func everyErrorExplainsWhatFailed(error: HandoffError) {
        let description = error.errorDescription ?? ""
        #expect(description.contains("failed") || description.contains("stopped"))
    }
}

@MainActor
@Suite struct StoreHandoffTests {
    private static let records: [[String: Any]] = [
        Fixtures.record(id: "map", name: "Pathfinder Flip-Mat: Carnival PDF", sku: "MAP", file: "map.pdf"),
        Fixtures.record(id: "pack", name: "Pathfinder Flip-Mat: Multi-Pack Download", sku: "PACK", file: "pack.zip"),
        Fixtures.record(id: "jpgs", name: "Pathfinder Flip-Tiles JPGs", sku: "JPGS", file: "tiles.zip")
    ]

    private let harness = StoreHarness(records: StoreHandoffTests.records)

    private func request(_ sku: String) -> HandoffRequest {
        HandoffRequest(sku: sku, app: .mapsmith)
    }

    @Test func downloadsAMissingTitleThenReturnsItsFile() async throws {
        let store = await harness.makeSyncedStore()

        let files = try await store.handoffFiles(for: request("MAP"))

        #expect(files.map(\.pathExtension) == ["pdf"])
        #expect(files.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        #expect(harness.paizo.http.count(of: "https://s3.example/signed") == 1)
    }

    @Test func returnsATitleOnDiskWithoutDownloadingAgain() async throws {
        let store = await harness.makeSyncedStore()
        _ = try await store.handoffFiles(for: request("MAP"))

        let files = try await store.handoffFiles(for: request("MAP"))

        #expect(files.count == 1)
        #expect(harness.paizo.http.count(of: "https://s3.example/signed") == 1)
    }

    @Test func downloadsAnOutdatedCopyAgain() async throws {
        let updated = "Wed Sep 02 2020 20:52:57 GMT+0000 (Coordinated Universal Time)"
        let revised = StoreHarness(records: [Fixtures.record(Fixtures.RecordFields(
            id: "map", name: "Flip-Mat: Bigger Dungeon PDF", sku: "MAP", file: "map.pdf", updated: updated
        ))])
        let store = await revised.makeSyncedStore()
        let file = try #require(try await store.handoffFiles(for: request("MAP")).first)
        let earlier = Date(timeIntervalSince1970: 1_500_000_000)
        try FileManager.default.setAttributes([.creationDate: earlier], ofItemAtPath: file.path)

        _ = try await store.handoffFiles(for: request("MAP"))

        #expect(revised.paizo.http.count(of: "https://s3.example/signed") == 2)
    }

    @Test func sendsEveryAcceptedFileOfAnUnpackedArchive() async throws {
        let store = await harness.makeSyncedStore()
        let pack = try Fixtures.zipArchive(files: ["a.pdf": "x", "b.jpg": "y", "notes.txt": "z"])
        harness.paizo.http.on("https://s3.example/signed", data: pack)

        let files = try await store.handoffFiles(for: request("PACK"))

        #expect(files.map(\.lastPathComponent).sorted() == ["a.pdf", "b.jpg"])
    }

    @Test func refusesWhenTheArchiveHoldsNothingTheAppOpens() async throws {
        let store = await harness.makeSyncedStore()
        harness.paizo.http.on("https://s3.example/signed", data: try Fixtures.zipArchive(files: ["notes.txt": "z"]))

        await #expect(throws: HandoffError.noAcceptedFiles(title: "Pathfinder Flip-Mat: Multi-Pack", app: "Mapsmith")) {
            try await store.handoffFiles(for: request("PACK"))
        }
    }

    @Test func reportsAFailedDownload() async throws {
        let store = await harness.makeSyncedStore()
        harness.paizo.http.on("https://s3.example/signed", text: "denied", status: 403)

        await #expect {
            try await store.handoffFiles(for: request("MAP"))
        } throws: { error in
            guard case .downloadFailed = error as? HandoffError else { return false }
            return true
        }
    }

    @Test func reportsAnInterruptedDownload() async throws {
        let store = await harness.makeSyncedStore()
        harness.paizo.http.on("https://s3.example/signed") { _ in throw URLError(.networkConnectionLost) }

        await #expect {
            try await store.handoffFiles(for: request("MAP"))
        } throws: { error in
            error as? HandoffError == .downloadFailed(title: "Pathfinder Flip-Mat: Carnival",
                                                      reason: "the connection was lost.")
        }
    }

    @Test func waitsItsTurnBehindOtherDownloads() async throws {
        let records = (1...6).map { Fixtures.record(id: "p\($0)", name: "Flip-Mat \($0) PDF", sku: "SKU\($0)") }
        let busy = StoreHarness(records: records)
        let store = await busy.makeSyncedStore()
        for item in store.items where item.sku != "SKU6" {
            store.download(store.locator.target(for: item.editions[0], in: item))
        }

        let files = try await store.handoffFiles(for: HandoffRequest(sku: "SKU6", app: .mapsmith))

        #expect(files.count == 1)
    }

    @Test func aRequestArrivingAtLaunchWaitsForTheCatalog() async throws {
        _ = await harness.makeSyncedStore()
        let store = harness.makeStore()
        #expect(!store.isLoaded)

        async let files = store.handoffFiles(for: request("MAP"))
        await store.start()

        #expect(try await files.count == 1)
    }

    @Test func refusesTitlesWithoutAnEditionToDownload() async {
        let store = await harness.makeSyncedStore()
        await #expect(throws: HandoffError.noEdition(title: "Pathfinder Flip-Tiles JPGs")) {
            try await store.handoffFiles(for: request("JPGS"))
        }
    }

    @Test func refusesUnknownTitles() async {
        let store = await harness.makeSyncedStore()
        await #expect(throws: HandoffError.titleNotFound(sku: "NOPE")) {
            try await store.handoffFiles(for: request("NOPE"))
        }
    }

    @Test func refusesWhenSignedOut() async {
        let store = StoreHarness(account: nil).makeStore()
        await store.start()
        await #expect(throws: HandoffError.signedOut) {
            try await store.handoffFiles(for: request("MAP"))
        }
    }
}
