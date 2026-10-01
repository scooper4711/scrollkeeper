import Foundation
@testable import PaizoLibraryKit
import Testing

/// Collects the pages a synchronizer reports.
private actor PageLog {
    private(set) var pages: [SyncPage] = []

    func append(_ page: SyncPage) {
        pages.append(page)
    }

    var identifiers: Set<String> { Set(pages.flatMap(\.entitlements).map(\.packageID)) }
}

@Suite struct CatalogSynchronizerTests {
    private let paizo = FakePaizo()
    private let log = PageLog()

    private func makeSynchronizer(recordCount: Int, pageSize: Int = 2) -> CatalogSynchronizer {
        paizo.installSignedInStore()
        let records = (0..<recordCount).map { Fixtures.record(id: "p\($0 + 1)", name: "Book \($0 + 1)") }
        paizo.installLibrary(records: records, pageSize: pageSize)
        let session = PaizoSession(http: paizo.http, credentials: MemoryCredentialStore(FakePaizo.account))
        return CatalogSynchronizer(client: LibraryCatalogClient(http: paizo.http, session: session))
    }

    private func record(_ page: SyncPage) async {
        await log.append(page)
    }

    @Test func fetchAllWalksEveryPageAndReportsRunningTotals() async throws {
        try await makeSynchronizer(recordCount: 17).fetchAll(onPage: record)

        let pages = await log.pages
        #expect(await log.identifiers.count == 17)
        #expect(pages.count == 9)
        #expect(pages.first?.entitlements.map(\.packageID) == ["p1", "p2"])
        #expect(pages.last?.fetchedCount == 17)
        #expect(pages.allSatisfy { $0.totalCount == 17 })
        #expect(paizo.http.count(of: "customer-library") == 9)
    }

    @Test func fetchAllStopsAfterOnePageWhenThatIsEverything() async throws {
        try await makeSynchronizer(recordCount: 2).fetchAll(onPage: record)
        #expect(paizo.http.count(of: "customer-library") == 1)
    }

    @Test func fetchAllHandlesAnEmptyLibrary() async throws {
        try await makeSynchronizer(recordCount: 0).fetchAll(onPage: record)
        #expect(await log.pages == [SyncPage(entitlements: [], fetchedCount: 0, totalCount: 0)])
    }

    @Test func failedPageIsRetriedOnce() async throws {
        let synchronizer = makeSynchronizer(recordCount: 4)
        let attempts = Counter()
        paizo.http.on("customer-library?token=\(FakePaizo.token)&page=2") { request in
            if attempts.increment() == 1 {
                return HTTPResponse(data: Data(), statusCode: 503, finalURL: request.url)
            }
            let html = Fixtures.libraryPageHTML(records: [Fixtures.record(id: "late", name: "Late")], count: 4)
            return HTTPResponse(data: Data(html.utf8), finalURL: request.url)
        }

        try await synchronizer.fetchAll(onPage: record)
        #expect(await log.identifiers.contains("late"))
        #expect(attempts.current == 2)
    }

    @Test func pageThatKeepsFailingStopsTheSyncButKeepsEarlierPages() async {
        let synchronizer = makeSynchronizer(recordCount: 4)
        paizo.http.on("customer-library?token=\(FakePaizo.token)&page=2", text: "", status: 500)

        await #expect(throws: PaizoError.http(operation: "Loading library page 2", status: 500)) {
            try await synchronizer.fetchAll(onPage: record)
        }
        #expect(await log.identifiers == ["p1", "p2"])
    }

    @Test func fetchNewStopsAtFirstPageWithNothingUnknown() async throws {
        let synchronizer = makeSynchronizer(recordCount: 6)
        try await synchronizer.fetchNew(knownIDs: ["p2", "p3", "p4", "p5", "p6"], onPage: record)

        let pages = await log.pages
        #expect(pages.map { $0.entitlements.map(\.packageID) } == [["p1"], []])
        #expect(pages.last?.fetchedCount == 6)
        #expect(paizo.http.count(of: "customer-library") == 2)
    }

    @Test func fetchNewReadsToTheLastPageWhenEverythingIsNew() async throws {
        try await makeSynchronizer(recordCount: 5).fetchNew(knownIDs: [], onPage: record)
        #expect(await log.identifiers.count == 5)
        #expect(paizo.http.count(of: "customer-library") == 3)
    }

    @Test func cancelledSyncStopsBeforeAskingPaizo() async {
        let synchronizer = makeSynchronizer(recordCount: 4)
        let task = Task {
            try await Task.sleep(for: .seconds(30))
            try await synchronizer.fetchAll(onPage: record)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(paizo.http.count(of: "customer-library") == 0)
    }

    @Test(arguments: [(3032, 50, 61), (50, 50, 1), (51, 50, 2), (0, 0, 1), (10, 0, 1)])
    func pageCountRoundsUp(total: Int, pageSize: Int, expected: Int) {
        #expect(CatalogSynchronizer.pageCount(total: total, pageSize: pageSize) == expected)
    }
}

@Suite struct MetadataSynchronizerTests {
    private let paizo = FakePaizo()
    private let directory = TemporaryDirectory()

    private var covers: CoverStore { CoverStore(directory: directory.url.appending(path: "Covers")) }

    private func makeSynchronizer() -> MetadataSynchronizer {
        MetadataSynchronizer(storefront: StorefrontClient(http: paizo.http), http: paizo.http, covers: covers)
    }

    @Test func returnsMetadataForEverySKUAndCachesCovers() async {
        paizo.installStorefront(products: ["PZO1E": FakePaizo.productNode(sku: "PZO1E", name: "Adventure One")])

        let metadata = await makeSynchronizer().fetch([
            MetadataRequest(sku: "PZO1E", fallbackImageURL: "https://cdn.example/sample.jpg"),
            MetadataRequest(sku: "PZOGONE"),
            MetadataRequest(sku: "PZOOLD", fallbackImageURL: "https://cdn.example/old-sample.jpg")
        ])

        #expect(metadata.map(\.sku) == ["PZO1E", "PZOGONE", "PZOOLD"])
        #expect(metadata[0].coverURL == "https://cdn.example/PZO1E.jpg")
        #expect(metadata[1].isEmpty)
        #expect(metadata[2].isEmpty)
        #expect(metadata[2].coverURL == "https://cdn.example/old-sample.jpg")
        #expect(covers.hasCover(sku: "PZO1E"))
        #expect(!covers.hasCover(sku: "PZOGONE"))
        #expect(covers.hasCover(sku: "PZOOLD"))
        #expect((try? Data(contentsOf: covers.url(sku: "PZO1E"))) == Data("jpeg-bytes".utf8))
    }

    @Test func doesNotDownloadACoverTwice() async {
        paizo.installStorefront(products: ["PZO1E": FakePaizo.productNode(sku: "PZO1E", name: "Adventure One")])
        _ = await makeSynchronizer().fetch([MetadataRequest(sku: "PZO1E")])
        _ = await makeSynchronizer().fetch([MetadataRequest(sku: "PZO1E")])
        #expect(paizo.http.count(of: "https://cdn.example/PZO1E.jpg") == 1)
    }

    @Test func keepsMetadataWhenTheCoverCannotBeFetched() async {
        paizo.installStorefront(products: ["PZO1E": FakePaizo.productNode(sku: "PZO1E", name: "Adventure One")])
        paizo.http.on("https://cdn.example/", text: "gone", status: 404)

        #expect(await makeSynchronizer().fetch([MetadataRequest(sku: "PZO1E")]).first?.name == "Adventure One")
        #expect(!covers.hasCover(sku: "PZO1E"))
    }

    @Test func returnsNothingWhenTheStorefrontIsUnreachable() async {
        #expect(await makeSynchronizer().fetch([MetadataRequest(sku: "PZO1E")]).isEmpty)
    }
}
