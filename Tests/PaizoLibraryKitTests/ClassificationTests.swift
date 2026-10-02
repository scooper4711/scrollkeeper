import Foundation
@testable import PaizoLibraryKit
import Testing

@Suite struct ClassifierTests {
    private let classifier = Classifier()

    private func classify(_ title: String, sku: String = "", metadata: ProductMetadata = .empty) -> Classification {
        classifier.classify(ClassificationInput(title: title, sku: sku, metadata: metadata, formats: ["PDF"]))
    }

    @Test(arguments: [
        ("Pathfinder Adventure Path #175: Broken Tusk Moon (Quest for the Frozen Flame 1 of 3)",
         ProductLine.adventurePath),
        ("Pathfinder Adventure Path: War for the Crown Player's Guide", .adventurePath),
        ("Pathfinder Module: Cradle of Night", .adventure),
        ("Starfinder Adventure: Redshift Rally", .adventure),
        ("Pathfinder Society Scenario #3-25: Storming the Diamond Gate", .societyScenario),
        ("Starfinder Society Special #5-99: Battle for the Bulwark", .societyScenario),
        ("Starfinder Second Edition Playtest Scenario 2: It Came from the Vast!", .societyScenario),
        ("Starfinder Scenario #2-16: A Scoured Home", .societyScenario),
        ("Pathfinder Special: Race for the Runecarved Key", .societyScenario),
        ("Pathfinder Quest (Series 2) #17: Escorting a Mirage", .quest),
        ("Pathfinder Bounty #7: Cleanup Duty", .bounty),
        ("Starfinder One-Shot #1: Band on the Run", .oneShot),
        ("Pathfinder Flip-Mat Classics: Haunted Dungeon", .maps),
        ("Pathfinder Campaign Setting: Strange Aeons Poster Map Folio", .maps),
        ("Pathfinder Adventure Path: Iron Gods Interactive Maps", .maps),
        ("Pathfinder Pawns: Hell's Vengeance Pawn Collection", .pawns),
        ("Pathfinder Spell Cards: Arcane", .cards),
        ("Pathfinder Tales: Faithful Servants", .fiction),
        ("Pathfinder Player Companion: Blood of the Elements", .playerCompanion),
        ("Pathfinder Lost Omens World Guide", .setting),
        ("Pathfinder Roleplaying Game: Mythic Adventures (OGL)", .rulebook),
        ("Community Use Package: World Map", .communityUse),
        ("Godsrain Audiobook", .other)
    ])
    func detectsProductLineFromTitle(title: String, expected: ProductLine) {
        #expect(classify(title).productLine == expected)
    }

    @Test func fallsBackToStoreCategoryForProductLine() {
        let metadata = Fixtures.metadata(sku: "PZO22005E", categories: ["Starfinder", "Rulebooks", "Digital Editions"])
        #expect(classify("Starfinder Galactic Ancestries", metadata: metadata).productLine == .rulebook)
    }

    @Test(arguments: [
        ("Pathfinder Society Scenario #7-08: The Haunted Corridor", "PZOPSS0708E", "", GameSystem.pathfinder1),
        ("Pathfinder Society Scenario #3-18: Delightful Disaster", "PZOPFS0318E", "", .pathfinder2),
        ("Starfinder Society Scenario #1-21: Breaching the Wreck", "PZOSFS0121E", "", .starfinder1),
        ("Starfinder Society Scenario #2-05: File Corrupted", "PZO260205E", "", .starfinder2),
        ("Starfinder Flip-Mat: Cantina (S2)", "", "", .starfinder2),
        ("Starfinder Pact Worlds", "PZO7107E", "Starfinder", .starfinder1),
        ("Starfinder Armory", "PZO7108E", "Starfinder 1E", .starfinder1),
        ("Pathfinder Society Scenario #8-06: Falling Sparks", "PZO160806E", "Pathfinder Society 2E", .pathfinder2),
        ("Pathfinder Society Scenario #8-06: Falling Sparks", "X", "Pathfinder Society 1E", .pathfinder1),
        ("Pathfinder Player Core", "PZO12001E", "Pathfinder 2E Remaster", .pathfinder2),
        ("Starfinder Society Scenario #1-01", "X", "Starfinder Society 2E", .starfinder2),
        ("Pathfinder Dark Archive", "PZO2111E", "Pathfinder 2E", .pathfinder2),
        ("Starfinder Galactic Ancestries", "X", "Starfinder 2E", .starfinder2),
        ("Pathfinder Adventure Path #169: Kindled Magic (Strength of Thousands 1 of 6)", "PZO90169E", "", .pathfinder2),
        ("Pathfinder Adventure Path #36: Sound of a Thousand Screams (Kingmaker 6 of 6)", "PZO9036E", "", .pathfinder1),
        ("Pathfinder NPC Core", "PZO12007E", "", .pathfinder2),
        ("Pathfinder Bounty #7: Cleanup Duty", "PZOPFB0007E", "", .pathfinder2),
        ("GameMastery Module D-1: Crown of the Kobold King (OGL)", "PZO9500-1E", "", .pathfinder1),
        ("Pathfinder Adventure Card Game: Rise of the Runelords Errata Cards", "PZO6000E", "", .cardGame),
        ("Liar's Blade", "PZO8510E", "", .other)
    ])
    func detectsGameSystem(title: String, sku: String, brand: String, expected: GameSystem) {
        let metadata = Fixtures.metadata(sku: sku, brand: brand)
        #expect(classify(title, sku: sku, metadata: metadata).gameSystem == expected)
    }

    @Test func recordsAdventurePathCampaignVolumeAndPart() {
        let result = classify("Pathfinder Adventure Path #81: Shifting Sands (Mummy\u{2019}s Mask 3 of 6)")
        #expect(result.series == "Mummy's Mask")
        #expect(result.number == 81)
        #expect(result.part == "3 of 6")
    }

    @Test func recordsCampaignOfUnnumberedAdventurePathProducts() {
        #expect(classify("Pathfinder Adventure Path: War for the Crown Player's Guide").series == "War for the Crown")
        #expect(classify("Pathfinder Hell's Destiny Adventure Path").series.isEmpty)
    }

    @Test func recordsSeasonForFirstEditionAndYearForSecond() {
        let first = classify("Pathfinder Society Scenario #7\u{2013}11: Ancients' Anguish", sku: "PZOPSS0711E")
        #expect(first.series == "Season 7")
        #expect(first.season == 7)
        #expect(first.number == 11)

        let second = classify("Pathfinder Society Scenario #4-13: Fortress of the Nail", sku: "PZOPFS0413E")
        #expect(second.series == "Year 4")

        let oldStyle = classify("Starfinder Society Scenario 1-12: Take the Bait", sku: "PZOSFS0112E")
        #expect(oldStyle.season == 1)
        #expect(oldStyle.number == 12)
    }

    @Test func scenarioWithoutNumberHasNoSeason() {
        let result = classify("Pathfinder Society Intro: Year of Boundless Wonder")
        #expect(result.season == nil)
        #expect(result.series.isEmpty)
    }

    @Test func recordsQuestAndBountyNumbers() {
        #expect(classify("Pathfinder Bounty #16: Boom Town Betrayal").number == 16)
        #expect(classify("Pathfinder Society Quest: Fane of Fangs (PFRPG)").number == nil)
    }

    @Test func readsLevelFromSummaryAndKeepsFormats() {
        let summary = "A Starfinder Society Scenario designed for 1st- through 2nd-level characters."
        let result = classify("Scenario", metadata: Fixtures.metadata(sku: "S", summary: summary))
        #expect(result.levelRange == 1...2)
        #expect(result.levelLabel == "1–2")
        #expect(result.formats == ["PDF"])
    }
}

@Suite struct LevelRangeParserTests {
    @Test(arguments: [
        ("designed for 9th- through 12th-level characters", 9, 12),
        ("A Pathfinder Society adventure for 5th-6th level characters, playable in 2-3 hours.", 5, 6),
        ("An adventure for 1st to 4th level characters", 1, 4),
        ("Pathfinder Society Scenario for Levels 5-8", 5, 8),
        ("Tier 1\u{2013}5", 1, 5),
        ("a deadly dungeon for 5th-level characters", 5, 5),
        ("written for four 1st-level characters", 1, 1)
    ])
    func parsesRanges(text: String, low: Int, high: Int) {
        #expect(LevelRangeParser.parse(text) == low...high)
    }

    @Test(arguments: ["A 224-page rulebook", "levels 30-40", "for 99th-level characters", "levels 8-3"])
    func ignoresTextWithoutPlausibleLevels(text: String) {
        #expect(LevelRangeParser.parse(text) == nil)
    }

    @Test func singleLevelLabel() {
        var classification = Classification()
        #expect(classification.levelLabel.isEmpty)
        classification.levelRange = 5...5
        #expect(classification.levelLabel == "5")
    }
}

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

    @Test func metadataKnowsWhenItIsEmptyAndBuildsStoreURL() {
        var metadata = ProductMetadata(sku: "S")
        #expect(metadata.isEmpty)
        #expect(metadata.storeURL == nil)
        metadata.storePath = "/pathfinder-dark-archive-pdf/"
        #expect(metadata.storeURL?.absoluteString == "https://store.paizo.com/pathfinder-dark-archive-pdf/")
    }
}
