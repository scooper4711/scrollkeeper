import Foundation
import PDFKit
@testable import ScrollkeeperKit
import TablesideShared
import Testing

/// The demo library's real PDFs, covers and free titles (library-manager 13.5, 13.6).
@MainActor
@Suite struct DemoLibraryTests {
    @Test func everyDemoPDFIsBundledAndEndsWithTheNotice() throws {
        let files = Set(DemoCatalog.titles.flatMap { $0.editions.map(\.file) }.filter { $0.hasSuffix(".pdf") })
        #expect(files.count == 10)
        for file in files {
            let url = try #require(DemoFiles.bundled(file), "\(file) isn't bundled")
            let document = try #require(PDFDocument(url: url), "\(file) isn't a PDF")
            let last = document.page(at: document.pageCount - 1)?.string ?? ""
            let isSample = file == "sample-monster-core.pdf"
            #expect(isSample || last.contains("Community Use Policy"), "\(file) has no notice")
        }
        #expect(DemoFiles.bundled("book.epub") == nil)
    }

    @Test func aTicketLeadsToTheRequestedFile() async throws {
        let client = DemoHTTPClient(downloadDuration: 0, outside: StubHTTPClient())
        let ticketURL = try #require(URL(string: "https://paizo.com/api/library/download"))
        let ticket = try await client.send(.postJSON(ticketURL,
                                                     orderedFields: [(name: "key", value: "map-forest.pdf")]))
        #expect(ticket.text == #"{"data":"map-forest.pdf"}"#)
        let signedURL = try #require(URL(string: "https://paizo.com/api/library/download/map-forest.pdf"))
        let signed = try await client.send(URLRequest(url: signedURL))
        #expect(signed.text.contains("files.demo.invalid\\/map-forest.pdf"))

        let destination = FileManager.default.temporaryDirectory.appending(path: "demo-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: destination) }
        try await client.download(URLRequest(url: URL(string: DemoFiles.address(of: "unknown.epub"))!),
                                  to: destination) { _ in }
        #expect(try Data(contentsOf: destination) == DemoFiles.placeholderPDF)
    }

    @Test func everyTitleHasADrawnCover() async throws {
        let client = DemoHTTPClient(downloadDuration: 0, outside: StubHTTPClient())
        let cover = try await client.send(URLRequest(url: URL(string: "https://covers.demo.invalid/DEMO7001E.jpg")!))
        #expect(cover.statusCode == 200 && cover.data.starts(with: [0xFF, 0xD8]))
        let missing = try await client.send(URLRequest(url: URL(string: "https://covers.demo.invalid/NOPE.jpg")!))
        #expect(missing.statusCode == 404)
        #expect(DemoCatalog.product(sku: "DEMO7001E")?["defaultImage"] != nil)
    }

    @Test func theFreeTitlesDownloadFromPaizo() async throws {
        let paizo = StubHTTPClient()
        paizo.on("downloads.paizo.com", data: Data("%PDF-free".utf8))
        let store = LibraryStore(environment: .demo(downloadDuration: 0.01, outside: paizo))
        await store.start()
        await store.waitUntilIdle()
        let free = try #require(store.item(id: BuiltInTitles.webSupplementSKU))
        let target = try #require(store.quickActions(for: free).download)

        store.download(target)
        await store.waitForDownloads()

        #expect(try Data(contentsOf: target.localURL) == Data("%PDF-free".utf8))
        #expect(paizo.count(of: "downloads.paizo.com") == 1)
    }
}

/// Sharing the demo through the App Group only when no real library is there (library-manager 13.7).
@Suite struct DemoSharingTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "Scrollkeeper-\(UUID())")

    private func write(_ path: String) throws {
        let file = folder.appending(path: path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: file)
    }

    @Test func sharesAnEmptyFolderAndMarksIt() throws {
        var environment = LibraryEnvironment.demo(outside: StubHTTPClient())
        environment.useDemoToolkitFolder(folder)

        #expect(environment.toolkitFolder == folder)
        #expect(environment.defaultDownloadDirectory.path == folder.appending(path: "Files").path)
        #expect(environment.coversDirectory.path == folder.appending(path: "Covers").path)
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: DemoSharing.markName).path))
        #expect(environment.libraryIndexURL != nil)
    }

    @Test func leavesARealLibraryAlone() throws {
        try write(ScrollkeeperLibrary.fileName)
        var environment = LibraryEnvironment.demo(outside: StubHTTPClient())
        environment.useDemoToolkitFolder(folder)
        #expect(environment.toolkitFolder == nil)

        let downloadsOnly = folder.appending(path: "other")
        try FileManager.default.createDirectory(at: downloadsOnly.appending(path: "Files/Book"),
                                                withIntermediateDirectories: true)
        #expect(!DemoSharing.canShare(in: downloadsOnly))
    }

    @Test func aRealLaunchRemovesWhatTheDemoShared() throws {
        try DemoSharing.claim(folder)
        try write("Files/Sample Adventure/Sample Adventure PDF.pdf")
        try write("Covers/DEMO1001E.jpg")
        try write(ScrollkeeperLibrary.fileName)
        #expect(DemoSharing.canShare(in: folder))

        DemoSharing.removeDemo(from: folder)

        let left = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        #expect(left.isEmpty)
    }

    @Test func aRealLaunchLeavesARealLibrary() throws {
        try write(ScrollkeeperLibrary.fileName)
        DemoSharing.removeDemo(from: folder)
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: ScrollkeeperLibrary.fileName).path))
    }
}

/// Ending the demo library from the app (#44).
@MainActor
@Suite struct DemoEndingTests {
    @Test func theDemoKnowsItIsTheDemoAndLeavesNothingBehind() async throws {
        let store = LibraryStore(environment: .demo(downloadDuration: 30, outside: StubHTTPClient()))
        await store.start()
        await store.waitUntilIdle()
        let item = try #require(store.item(id: "DEMO1003E"))
        store.download(try #require(store.quickActions(for: item).download))
        #expect(store.isDemo && !store.downloadJobs.isEmpty)
        let data = store.environment.dataDirectory
        #expect(FileManager.default.fileExists(atPath: data.path))

        store.endDemo()
        await store.waitForDownloads()

        #expect(store.downloadJobs.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: data.path))
    }

    @Test func aRealLibraryIsNotEnded() async throws {
        let harness = StoreHarness()
        let store = await harness.makeSyncedStore()
        #expect(!store.isDemo)
        store.endDemo()
        #expect(FileManager.default.fileExists(atPath: harness.environment.dataDirectory.path))
    }
}
