import Foundation
@testable import ScrollkeeperKit
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

    @Test func prefersTheStorefrontStartingLevelOverTheSummary() {
        var metadata = Fixtures.metadata(sku: "S", summary: "An adventure for 1st-level characters.")
        metadata.startingLevel = "10-14"
        #expect(classify("Pathfinder Adventure Path #125: Tower of the Drowned Dead", metadata: metadata)
            .levelRange == 10...14)
    }

    @Test func readsLevelFromSummaryAndKeepsFormats() {
        let summary = "A Starfinder Society Scenario designed for 1st- through 2nd-level characters."
        let result = classify("Scenario", metadata: Fixtures.metadata(sku: "S", summary: summary))
        #expect(result.levelRange == 1...2)
        #expect(result.levelLabel == "1–2")
        #expect(result.formats == ["PDF"])
    }
}

@Suite struct AuthorParserTests {
    @Test(arguments: [
        ("A Pathfinder Society adventure for 1st-2nd level characters.\nWritten by Kate Baker.", "Kate Baker"),
        ("Written by Rigby Bendele and Jacob W. Michaels\nScenario tags", "Rigby Bendele and Jacob W. Michaels"),
        ("Written by Solomon St. John\nContent note", "Solomon St. John"),
        ("Written by Hilary Moon Murphy. The following maps are used", "Hilary Moon Murphy"),
        ("Chapter 1: \"Stolen Land\"\nby Tim Hitchcock\nThe adventure begins", "Tim Hitchcock"),
        ("\u{201C}The Ruined Clouds\u{201D} by Jason Keeley.\r\nAn archive of new creatures", "Jason Keeley"),
        ("written by Luis Loza, Ron Lundeen, and Mikhail Rekun", "Luis Loza, Ron Lundeen, and Mikhail Rekun"),
        ("by Vincent van Gogh and", "Vincent van Gogh"),
        ("Written by Ben McFarland, Steven Helt.Cover Art by Someone", "Ben McFarland, Steven Helt")
    ])
    func findsTheCreditedAuthors(summary: String, expected: String) {
        #expect(AuthorParser.parse(summary) == expected)
    }

    @Test(arguments: [
        "This map can be used by experienced GMs and novices alike.",
        "Created by cartographer Jason A. Engle",
        "Written by the kishalee",
        "A 224-page rulebook",
        ""
    ])
    func ignoresTextThatIsNotACredit(summary: String) {
        #expect(AuthorParser.parse(summary).isEmpty)
    }
}

@Suite struct LevelRangeParserTests {
    @Test(arguments: [("10-14", 10, 14), ("5", 5, 5), (" 1 \u{2013} 4 ", 1, 4)])
    func parsesTheStartingLevelField(value: String, low: Int, high: Int) {
        #expect(LevelRangeParser.parseField(value) == low...high)
    }

    @Test(arguments: ["", "Any", "1-2-3", "40", "9-3"])
    func ignoresStartingLevelFieldsThatAreNotLevels(value: String) {
        #expect(LevelRangeParser.parseField(value) == nil)
    }

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
