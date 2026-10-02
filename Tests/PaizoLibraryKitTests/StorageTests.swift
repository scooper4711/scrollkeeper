import Foundation
@testable import PaizoLibraryKit
import Testing

@Suite struct LibraryRepositoryTests {
    private let directory = TemporaryDirectory()

    @Test func storesAndLoadsEveryPartOfTheCatalog() async throws {
        let repository = LibraryRepository(directory: directory.url.appending(path: "data"))
        var entitlement = Fixtures.entitlement("Book PDF", sku: "PZO1E")
        entitlement.dateGranted = Date(timeIntervalSince1970: 1_700_000_000)

        try await repository.save(entitlements: [entitlement])
        try await repository.save(metadata: ["PZO1E": Fixtures.metadata(sku: "PZO1E")])
        try await repository.save(tags: ["PZO1E": ["Played"]])

        let reloaded = await LibraryRepository(directory: directory.url.appending(path: "data")).load()
        #expect(reloaded.entitlements == [entitlement])
        #expect(reloaded.metadata["PZO1E"]?.name == "Product PZO1E")
        #expect(reloaded.tags == ["PZO1E": ["Played"]])
    }

    @Test func missingOrCorruptFilesLoadAsEmpty() async throws {
        try Data("not json".utf8).write(to: directory.url.appending(path: "catalog.json"))
        #expect(await LibraryRepository(directory: directory.url).load() == CatalogSnapshot())
    }
}

@Suite struct FinderTaggerTests {
    private let directory = TemporaryDirectory()

    @Test func writesAndReadsFinderTags() throws {
        let file = directory.url.appending(path: "book.pdf")
        try Data("pdf".utf8).write(to: file)
        let tagger = FinderTagger()

        #expect(tagger.tags(of: file).isEmpty)
        try tagger.setTags(["Played", "GM Prep"], on: file)
        #expect(Set(tagger.tags(of: file)) == ["Played", "GM Prep"])
        try tagger.setTags([], on: file)
        #expect(tagger.tags(of: file).isEmpty)
    }

    @Test func missingFileHasNoTagsAndCannotBeTagged() {
        let missing = directory.url.appending(path: "missing.pdf")
        #expect(FinderTagger().tags(of: missing).isEmpty)
        #expect(throws: (any Error).self) { try FinderTagger().setTags(["x"], on: missing) }
    }
}

@Suite struct FileLocatorTests {
    private let directory = TemporaryDirectory()

    private var locator: FileLocator { FileLocator(root: directory.url) }

    private func makeItem() -> LibraryTitle {
        let entitlements = [
            Fixtures.entitlement("Core: Rules PDF - Single File", sku: "PZO1E", productName: "Core: Rules PDF"),
            Fixtures.entitlement("Core: Rules PDF - File per Chapter", sku: "PZO1E", file: "x.zip",
                                 productName: "Core: Rules PDF")
        ]
        return EntitlementGrouper().makeItems(from: CatalogSnapshot(entitlements: entitlements))[0]
    }

    private func write(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
    }

    @Test func editionsLiveInAFolderNamedAfterTheTitle() {
        let item = makeItem()
        let target = locator.target(for: item.editions[0], in: item)

        #expect(target.localURL.path == directory.url.path + "/Core- Rules/Core- Rules PDF - Single File.pdf")
        #expect(target.itemID == "PZO1E")
        #expect(target.remote.fileName == "book.pdf")
        #expect(target.id == target.localURL.path)
        #expect(!target.isArchive)
        #expect(target.partialURL.lastPathComponent == "Core- Rules PDF - Single File.pdf.download")
    }

    @Test func archivesUnpackIntoAFolderNamedAfterTheirEdition() throws {
        let item = makeItem()
        let target = locator.target(for: item.editions[1], in: item)

        #expect(target.isArchive)
        #expect(target.localURL.path.hasSuffix("/Core- Rules/Core- Rules PDF - File per Chapter"))
        #expect(target.partialURL.lastPathComponent == "Core- Rules PDF - File per Chapter.download")
        #expect(!locator.isDownloaded(target))

        try write(target.localURL.appending(path: "10 Appendix.pdf"))
        try write(target.localURL.appending(path: "2 Classes.pdf"))
        try write(target.partialURL)

        #expect(locator.files(in: target).map(\.lastPathComponent) == ["2 Classes.pdf", "10 Appendix.pdf"])
        #expect(locator.isDownloaded(target))
        #expect(locator.localFiles(for: item).count == 2)
    }

    @Test func otherZipsAreSavedWhereTheUserChooses() {
        let entitlement = Fixtures.entitlement("Community Use Package: Runes", sku: "PZOCUP1E", file: "runes.zip")
        let item = EntitlementGrouper().makeItems(from: CatalogSnapshot(entitlements: [entitlement]))[0]
        let edition = item.editions[0]
        let destination = URL(filePath: "/Users/someone/Desktop/Runes.zip")

        #expect(edition.isSavedElsewhere)
        #expect(!edition.isUnpackedArchive)
        #expect(locator.suggestedFileName(for: edition, in: item) == "Community Use Package- Runes.zip")
        let target = locator.exportTarget(for: edition, in: item, destination: destination)
        #expect(target.localURL == destination)
        #expect(!target.isArchive)
        #expect(target.partialURL.lastPathComponent == "Runes.zip.download")
    }

    @Test func editionsSharingANameGetDistinctFiles() {
        var first = Fixtures.entitlement("Scenario #2-00", sku: "S")
        first.packageID = "aaaaaaaa-1111"
        var second = Fixtures.entitlement("Scenario #2-00", sku: "S")
        second.packageID = "bbbbbbbb-2222"
        let item = EntitlementGrouper().makeItems(from: CatalogSnapshot(entitlements: [first, second]))[0]
        let names = item.editions.map { locator.target(for: $0, in: item).localURL.lastPathComponent }

        #expect(Set(names) == ["Scenario #2-00 (aaaaaaaa).pdf", "Scenario #2-00 (bbbbbbbb).pdf"])
    }

    @Test func fileWithoutExtensionHasNoDot() {
        let entitlement = Fixtures.entitlement("Odd Package", sku: "S", file: "README")
        let item = EntitlementGrouper().makeItems(from: CatalogSnapshot(entitlements: [entitlement]))[0]
        #expect(locator.target(for: item.editions[0], in: item).localURL.lastPathComponent == "Odd Package")
    }

    @Test func findsFinishedFilesButNotPartialOrHiddenOnes() throws {
        let item = makeItem()
        let target = locator.target(for: item.editions[0], in: item)
        #expect(!locator.isDownloaded(target))
        #expect(locator.downloadedItemIDs(among: [item]).isEmpty)

        try write(target.localURL)
        try write(locator.folder(for: item).appending(path: "Chapters/01.pdf"))
        try write(locator.folder(for: item).appending(path: "half.pdf.download"))
        try write(locator.folder(for: item).appending(path: ".DS_Store"))

        #expect(locator.isDownloaded(target))
        #expect(locator.files(in: target) == [target.localURL])
        #expect(Set(locator.localFiles(for: item).map(\.lastPathComponent)) == [
            "Core- Rules PDF - Single File.pdf", "01.pdf"
        ])
        #expect(locator.downloadedItemIDs(among: [item]) == ["PZO1E"])
    }

    @Test func emptyTitleFolderDoesNotCountAsDownloaded() throws {
        let item = makeItem()
        try FileManager.default.createDirectory(at: locator.folder(for: item), withIntermediateDirectories: true)
        #expect(locator.downloadedItemIDs(among: [item]).isEmpty)
    }
}

@Suite struct ArchiveExtractorTests {
    private let directory = TemporaryDirectory()

    @Test func unpacksAnArchiveAndReplacesEarlierContents() throws {
        let archive = directory.url.appending(path: "chapters.zip.download")
        let prefixed = "beb8a193-ea1d-4e13-8808-263547a7f362-PZO1E Maps.pdf"
        try Fixtures.zipArchive(files: ["01 Intro.pdf": "intro", "Maps/02 Map.pdf": "map", prefixed: "maps"])
            .write(to: archive)
        let destination = directory.url.appending(path: "Chapters", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: destination.appending(path: "stale.pdf"))

        try ArchiveExtractor().extract(archive, to: destination)

        #expect(try String(contentsOf: destination.appending(path: "01 Intro.pdf"), encoding: .utf8) == "intro")
        #expect(try String(contentsOf: destination.appending(path: "Maps/02 Map.pdf"), encoding: .utf8) == "map")
        #expect(try String(contentsOf: destination.appending(path: "PZO1E Maps.pdf"), encoding: .utf8) == "maps")
        #expect(!FileManager.default.fileExists(atPath: destination.appending(path: "stale.pdf").path))
    }

    @Test func damagedArchiveFailsAndLeavesNothingBehind() throws {
        let archive = directory.url.appending(path: "broken.zip")
        try Data("this is not a zip archive".utf8).write(to: archive)
        let destination = directory.url.appending(path: "Broken", directoryHint: .isDirectory)

        #expect(throws: ArchiveError.self) { try ArchiveExtractor().extract(archive, to: destination) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.url.path) == ["broken.zip"])
    }

    @Test func errorNamesTheArchive() {
        let error = ArchiveError(archiveName: "chapters.zip", detail: "the archive is damaged.")
        #expect(error.errorDescription == "Unpacking chapters.zip failed: the archive is damaged.")
    }
}

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
        #expect(titles({ $0.downloadedOnly = true }, downloaded: ["PZO8500E"]) == ["PZO8500E"])
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
        query.downloadedOnly = true
        query.gameSystem = .other
        query.productLine = .maps
        #expect(query.hasFilters)
        query.clearFilters()
        #expect(query == LibraryQuery())
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
        let suite = "PaizoLibraryKitTests-" + UUID().uuidString
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let settings = SettingsStore(suiteName: suite)

        #expect(settings.downloadDirectoryPath.isEmpty)
        settings.downloadDirectoryPath = "/Volumes/Books"
        #expect(SettingsStore(suiteName: suite).downloadDirectoryPath == "/Volumes/Books")
    }

    @Test func liveEnvironmentKeepsDataInApplicationSupport() {
        let environment = LibraryEnvironment.live()
        #expect(environment.dataDirectory.path.hasSuffix("Library/Application Support/Paizo Library Manager"))
        #expect(environment.defaultDownloadDirectory.lastPathComponent == "Files")
    }

    @Test func coverFileNamesAreSafe() {
        let covers = CoverStore(directory: URL(filePath: "/tmp/covers"))
        #expect(covers.url(sku: "PZO9500/1E").lastPathComponent == "PZO9500-1E.jpg")
    }
}
