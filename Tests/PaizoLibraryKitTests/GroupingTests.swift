import Foundation
@testable import PaizoLibraryKit
import Testing

@Suite struct EntitlementGrouperTests {
    private let grouper = EntitlementGrouper()

    @Test func groupsEditionsOfOneProductInKindOrder() {
        let entitlements = [
            Fixtures.entitlement("Pathfinder NPC Core PDF - File per Chapter", sku: "PZO12007E", file: "c.zip",
                                 productName: "Pathfinder NPC Core PDF"),
            Fixtures.entitlement("Pathfinder NPC Core PDF - Single File", sku: "PZO12007E",
                                 productName: "Pathfinder NPC Core PDF"),
            Fixtures.entitlement("Pathfinder Flip-Mat: Carnival PDF", sku: "PZO30100E")
        ]
        let items = grouper.makeItems(from: CatalogSnapshot(entitlements: entitlements))

        #expect(items.map(\.title) == ["Pathfinder NPC Core", "Pathfinder Flip-Mat: Carnival"])
        #expect(items[0].editions.map(\.label) == ["Single File", "File per Chapter"])
        #expect(items[0].editions[1].isUnpackedArchive)
        #expect(!items[0].editions[0].isUnpackedArchive)
        #expect(!items[0].editions[1].isSavedElsewhere)
        #expect(items[0].classification.formats == ["PDF", "ZIP"])
        #expect(items[0].formatsLabel == "PDF, ZIP")
        #expect(items[1].editions.map(\.label) == ["PDF"])
    }

    @Test(arguments: [
        ("Pathfinder Society Scenario #6-15: Lost and Forgotten", "s.zip", true, false),
        ("Starfinder One-Shot #1: Band on the Run", "o.zip", true, false),
        ("Pathfinder Hell's Destiny Adventure Path - Single File", "h.zip", true, false),
        ("Community Use Package: Runes", "r.zip", false, true),
        ("Pathfinder Flip-Mat: Coastline - JPGs", "j.zip", false, true),
        ("Pathfinder Roleplaying Game Compatible Logos (Download)", "l.zip", false, true),
        ("Godsrain Audiobook", "a.zip", false, true),
        ("Pathfinder Flip-Mat: Coastline PDF", "c.pdf", false, false)
    ])
    func decidesWhichZipsAreUnpacked(name: String, file: String, unpacked: Bool, savedElsewhere: Bool) {
        let entitlement = Fixtures.entitlement(name, sku: "S", file: file)
        let edition = grouper.makeItems(from: CatalogSnapshot(entitlements: [entitlement]))[0].editions[0]
        #expect(edition.isUnpackedArchive == unpacked)
        #expect(edition.isSavedElsewhere == savedElsewhere)
    }

    @Test func entitlementWithoutSKUBecomesItsOwnTitle() {
        var entitlement = Fixtures.entitlement("Mystery Package", file: "")
        entitlement.providedBySKU = "undefined"
        let items = grouper.makeItems(from: CatalogSnapshot(entitlements: [entitlement]))

        #expect(items.first?.id == entitlement.packageID)
        #expect(items.first?.sku.isEmpty == true)
        #expect(items.first?.editions.first?.label == "Unavailable")
    }

    @Test func labelsEditionsByWhatDistinguishesThem() {
        let product = "Pathfinder Dark Archive PDF"
        let names = [
            "Pathfinder Dark Archive Remastered PDF - File per Chapter",
            "Lost Page from the Dark Archive - 11 PDF",
            "Pathfinder Dark Archive (S2) - JPGs",
            "Pathfinder Dark Archive (Download) - JPGs",
            "Pathfinder Dark-Archive PDF - Assembled Maps"
        ]
        let entitlements = names.map { Fixtures.entitlement($0, sku: "PZO2111E", productName: product) }
        let labels = grouper.makeItems(from: CatalogSnapshot(entitlements: entitlements))[0].editions.map(\.label)

        #expect(Set(labels) == [
            "Remastered – File per Chapter", "Lost Page from the Dark Archive - 11", "(S2) - JPGs", "JPGs",
            "Assembled Maps"
        ])
    }

    @Test func completesProductNamesThatPaizoTruncated() {
        let truncated = "Pathfinder Society Scenario #5-19: Demonic Afterpa"
        let entitlement = Fixtures.entitlement(
            "Pathfinder Society Scenario #5-19: Demonic Afterparty", sku: "PZOPSS0519E", productName: truncated
        )
        let items = grouper.makeItems(from: CatalogSnapshot(entitlements: [entitlement]))
        #expect(items[0].title == "Pathfinder Society Scenario #5-19: Demonic Afterparty")
        #expect(items[0].editions[0].label == "PDF")
    }

    @Test func keepsTruncatedNameWhenNothingCompletesIt() {
        let truncated = String(repeating: "x", count: 50)
        let entitlement = Fixtures.entitlement("Something else", sku: "S", productName: truncated)
        #expect(grouper.makeItems(from: CatalogSnapshot(entitlements: [entitlement]))[0].title == truncated)
    }

    @Test func attachesMetadataTagsAndSearchText() {
        let entitlement = Fixtures.entitlement("Pathfinder Bounty #7: Cleanup Duty", sku: "PZOPFB0007E")
        let snapshot = CatalogSnapshot(
            entitlements: [entitlement],
            metadata: ["PZOPFB0007E": Fixtures.metadata(sku: "PZOPFB0007E", summary: "For 1st-level characters.")],
            tags: ["PZOPFB0007E": ["Played"]]
        )
        let item = grouper.makeItems(from: snapshot)[0]

        #expect(item.tags == ["Played"])
        #expect(item.tagsLabel == "Played")
        #expect(item.metadata.coverURL.hasSuffix("PZOPFB0007E.jpg"))
        #expect(item.searchText.contains("cleanup duty"))
        #expect(item.author.isEmpty)
        #expect(item.searchText.contains("played"))
        #expect(item.searchText.contains("bounties"))
        #expect(item.levelSortKey == 1)
        #expect(item.numberSortKey == 7)
        #expect(item.productLineLabel == "Bounties")
        #expect(item.gameSystemLabel == "Pathfinder 2E")
    }

    @Test func titleWithoutAnyNameIsUntitled() {
        let items = grouper.makeItems(from: CatalogSnapshot(entitlements: [Fixtures.entitlement("PDF", sku: "S")]))
        #expect(items[0].title == "Untitled")
    }

    @Test func itemDefaultsWhenClassificationIsUnknown() {
        let item = LibraryTitle(id: "i", sku: "", title: "T", editions: [])
        #expect(item.dateAdded == .distantPast)
        #expect(item.levelSortKey == Int.max)
        #expect(item.numberSortKey == Int.max)
        #expect(item.fallbackImageURL.isEmpty)
        #expect(item.pageCount == 0)
        #expect(item.series.isEmpty)
    }
}

@Suite struct ModelLabelTests {
    @Test func everyGameSystemAndProductLineHasLabelAndSymbol() {
        #expect(GameSystem.allCases.allSatisfy { !$0.label.isEmpty && $0.id == $0.rawValue })
        #expect(ProductLine.allCases.allSatisfy { !$0.label.isEmpty && !$0.symbolName.isEmpty && $0.id == $0.rawValue })
        #expect(Set(EditionKind.allCases.map(\.label)).count == EditionKind.allCases.count)
    }

    @Test func metadataWrittenByAnOlderVersionStillLoads() throws {
        let older = #"{"sku":"PZO1E","name":"Old","coverURL":"https://cdn.example/a.jpg","pageCount":64}"#
        let metadata = try JSONDecoder().decode(ProductMetadata.self, from: Data(older.utf8))
        #expect(metadata.name == "Old")
        #expect(metadata.pageCount == 64)
        #expect(metadata.author.isEmpty)
        #expect(metadata.startingLevel.isEmpty)
        #expect(metadata.categoryPath.isEmpty)
    }

    @Test func titlesCanBeFoundByAuthor() {
        var metadata = Fixtures.metadata(sku: "PZO1E")
        metadata.author = "Tim Hitchcock"
        let snapshot = CatalogSnapshot(
            entitlements: [Fixtures.entitlement("Stolen Land PDF", sku: "PZO1E")], metadata: ["PZO1E": metadata]
        )
        let item = EntitlementGrouper().makeItems(from: snapshot)[0]
        #expect(item.author == "Tim Hitchcock")
        #expect(item.searchText.contains("tim hitchcock"))
    }

    @Test func metadataKnowsWhenItIsEmptyAndBuildsStoreURL() {
        var metadata = ProductMetadata(sku: "S")
        #expect(metadata.isEmpty)
        #expect(metadata.storeURL == nil)
        metadata.storePath = "/pathfinder-dark-archive-pdf/"
        #expect(metadata.storeURL?.absoluteString == "https://store.paizo.com/pathfinder-dark-archive-pdf/")
    }
}
