import Foundation
@testable import ScrollkeeperKit
import Testing

@Suite struct LibraryQueryTests {
    private let items: [LibraryTitle]

    init() {
        var bounty = Fixtures.entitlement("Pathfinder Bounty #7: Cleanup Duty", sku: "PZOPFB0007E")
        bounty.dateGranted = Date(timeIntervalSince1970: 2)
        let snapshot = CatalogSnapshot(
            entitlements: [
                bounty,
                Fixtures.entitlement("Starfinder Flip-Mat: Cantina PDF", sku: "PZO7300E", file: "map.zip"),
                Fixtures.entitlement("Pathfinder Tales: Nightglass ePub", sku: "PZO8500E", file: "n.epub")
            ],
            metadata: ["PZOPFB0007E": Fixtures.metadata(sku: "PZOPFB0007E", summary: "For 1st- to 4th-level heroes.")],
            tags: ["PZOPFB0007E": ["Played"], "PZO7300E": ["Played", "Table 10"]]
        )
        items = EntitlementGrouper().makeItems(from: snapshot)
    }

    private func titles(_ configure: (inout LibraryQuery) -> Void, downloaded: Set<String> = []) -> [String] {
        var query = LibraryQuery()
        configure(&query)
        return query.filter(items, downloadedIDs: downloaded).map(\.sku)
    }

    @Test func scopesSelectPartsOfTheLibrary() {
        #expect(titles { $0.scope = .all }.count == 3)
        #expect(titles({ $0.scope = .downloaded }, downloaded: ["PZO7300E"]) == ["PZO7300E"])
        #expect(titles { $0.scope = .productLine(.maps) } == ["PZO7300E"])
        #expect(titles { $0.scope = .gameSystem(.starfinder1) } == ["PZO7300E"])
        #expect(titles { $0.scope = .tag("Played") } == ["PZOPFB0007E", "PZO7300E"])
    }

    @Test func filtersCombine() {
        #expect(titles { $0.gameSystem = .pathfinder2 } == ["PZOPFB0007E"])
        #expect(titles { $0.productLine = .fiction } == ["PZO8500E"])
        #expect(titles { $0.format = "ZIP" } == ["PZO7300E"])
        #expect(titles { $0.level = 3 } == ["PZOPFB0007E"])
        #expect(titles { $0.level = 9 }.isEmpty)
        #expect(titles({ $0.download = .downloaded }, downloaded: ["PZO8500E"]) == ["PZO8500E"])
        #expect(titles({ $0.download = .notDownloaded }, downloaded: ["PZO8500E"]) == ["PZOPFB0007E", "PZO7300E"])
        #expect(titles({ $0.download = .any }, downloaded: ["PZO8500E"]).count == 3)
        // The use it is meant for: what in a category is still missing.
        #expect(titles({ $0.scope = .tag("Played"); $0.download = .notDownloaded }, downloaded: ["PZO7300E"])
            == ["PZOPFB0007E"])
        #expect(titles { $0.scope = .tag("Played"); $0.format = "PDF" } == ["PZOPFB0007E"])
    }

    @Test func searchNeedsEveryWordAndIgnoresCase() {
        #expect(titles { $0.searchText = "CLEANUP bounty" } == ["PZOPFB0007E"])
        #expect(titles { $0.searchText = "table 10" } == ["PZO7300E"])
        #expect(titles { $0.searchText = "pzo8500e" } == ["PZO8500E"])
        #expect(titles { $0.searchText = "cleanup cantina" }.isEmpty)
        #expect(titles { $0.searchText = "   " }.count == 3)
    }

    @Test func knowsWhetherFiltersAreSetAndClearsThem() {
        var query = LibraryQuery()
        #expect(!query.hasFilters)
        query.level = 2
        query.format = "PDF"
        query.download = .notDownloaded
        query.gameSystem = .other
        query.productLine = .maps
        #expect(query.hasFilters)
        query.clearFilters()
        #expect(query == LibraryQuery())
    }

    @Test func downloadFilterLabelsAreDistinct() {
        #expect(Set(DownloadFilter.allCases.map(\.label)).count == 3)
        #expect(DownloadFilter.allCases.allSatisfy { $0.id == $0.rawValue })
    }

    @Test func facetsCountEveryScope() {
        let facets = LibraryFacets(items: items, downloadedIDs: ["PZO8500E"])
        #expect(facets.count(for: .all) == 3)
        #expect(facets.count(for: .downloaded) == 1)
        #expect(facets.count(for: .productLine(.bounty)) == 1)
        #expect(facets.count(for: .productLine(.rulebook)) == 0)
        #expect(facets.count(for: .gameSystem(.pathfinder2)) == 1)
        #expect(facets.count(for: .gameSystem(.cardGame)) == 0)
        #expect(facets.count(for: .tag("Played")) == 2)
        #expect(facets.count(for: .tag("Unused")) == 0)
        #expect(facets.sortedTags == ["Played", "Table 10"])
        #expect(facets.formats == ["EPUB", "PDF", "ZIP"])
    }

    @Test func titlesSortNaturally() {
        let keys = ["Bounty #10", "Bounty #2", "bounty #1"].map(LibraryTitle.naturalSortKey).sorted()
        #expect(keys == ["bounty #000001", "bounty #000002", "bounty #000010"])
        #expect(LibraryTitle.naturalSortKey("Year 1234567") == "year 1234567")
    }
}

@Suite struct CoverStoreAndSettingsTests {
    @Test func settingsRememberTheDownloadFolder() {
        let suite = "ScrollkeeperKitTests-" + UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let settings = SettingsStore(suiteName: suite)

        #expect(settings.downloadDirectoryPath.isEmpty)
        settings.downloadDirectoryPath = "/Volumes/Books"
        #expect(SettingsStore(suiteName: suite).downloadDirectoryPath == "/Volumes/Books")
    }

    @Test func liveEnvironmentKeepsDataInApplicationSupport() {
        let environment = LibraryEnvironment.live()
        #expect(environment.dataDirectory.path.hasSuffix("Library/Application Support/Scrollkeeper"))
        #expect(environment.defaultDownloadDirectory.lastPathComponent == "Files")
    }

    @Test func coverFileNamesAreSafe() {
        let covers = CoverStore(directory: URL(filePath: "/tmp/covers"))
        #expect(covers.url(sku: "PZO9500/1E").lastPathComponent == "PZO9500-1E.jpg")
    }
}
