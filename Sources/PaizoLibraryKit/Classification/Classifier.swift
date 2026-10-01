import Foundation

/// What the classifier knows about a title.
public struct ClassificationInput: Sendable {
    public var title: String
    public var sku: String
    public var metadata: ProductMetadata
    public var formats: [String]

    public init(title: String, sku: String, metadata: ProductMetadata = .empty, formats: [String] = []) {
        self.title = title
        self.sku = sku
        self.metadata = metadata
        self.formats = formats
    }
}

/// Classifies a title by game system, product type, series and level.
public struct Classifier: Sendable {
    public init() {}

    public func classify(_ input: ClassificationInput) -> Classification {
        let title = TitleNormalizer.plainPunctuation(input.title)
        var result = Classification(
            gameSystem: GameSystemRules.gameSystem(title: title, sku: input.sku, brand: input.metadata.brand),
            productLine: ProductLineRules.productLine(title: title, categoryPath: input.metadata.categoryPath)
        )
        result.formats = input.formats
        result.levelRange = LevelRangeParser.parse(title) ?? LevelRangeParser.parse(input.metadata.summary)
        applySeries(to: &result, title: title)
        return result
    }

    private func applySeries(to result: inout Classification, title: String) {
        switch result.productLine {
        case .adventurePath:
            applyAdventurePath(to: &result, title: title)
        case .societyScenario:
            applySeason(to: &result, title: title)
        case .quest, .bounty, .oneShot:
            result.number = Self.hashNumber.captures(in: title).last.flatMap { Int($0) }
        default:
            break
        }
    }

    private func applyAdventurePath(to result: inout Classification, title: String) {
        let volume = Self.adventurePathVolume.captures(in: title)
        if volume.count == 5 {
            result.number = Int(volume[1])
            result.series = volume[2].trimmingCharacters(in: .whitespaces)
            result.part = "\(volume[3]) of \(volume[4])"
            return
        }
        let unnumbered = Self.adventurePathSeries.captures(in: title)
        if unnumbered.count == 2 {
            result.series = Self.adventurePathExtras.removingMatches(in: unnumbered[1])
                .trimmingCharacters(in: .whitespaces)
        }
    }

    private func applySeason(to result: inout Classification, title: String) {
        let captures = Self.seasonAndNumber.captures(in: title)
        guard captures.count == 3, let season = Int(captures[1]) else { return }
        result.season = season
        result.number = Int(captures[2])
        result.series = (result.gameSystem.isSecondEdition ? "Year " : "Season ") + String(season)
    }

    private static let adventurePathVolume = TextPattern(#"Adventure Path #(\d+):.*\((.+?)\s+(\d+) of (\d+)\)"#)
    private static let adventurePathSeries = TextPattern(#"Adventure Path:\s*(.+)$"#)
    private static let adventurePathExtras = TextPattern(
        #"\s+(Player'?s Guide|Interactive Maps|Poster Map Folio|Pawn Collection|Hardcover|Anniversary Edition).*$"#
    )
    private static let seasonAndNumber = TextPattern(
        #"(?:Scenario|Special|Intro)[^#\d]*#?\s*(\d{1,2})\s*-\s*(\d{1,3})"#
    )
    private static let hashNumber = TextPattern(#"#\s*(\d+)"#)
}

/// Ordered rules that decide the product type from the title, falling back to the store category.
enum ProductLineRules {
    static func productLine(title: String, categoryPath: [String]) -> ProductLine {
        if let rule = titleRules.first(where: { $0.pattern.matches(title) }) {
            return rule.line
        }
        let categories = categoryPath.joined(separator: " / ")
        return categoryRules.first(where: { $0.pattern.matches(categories) })?.line ?? .other
    }

    private struct Rule {
        let line: ProductLine
        let pattern: TextPattern

        init(_ line: ProductLine, _ pattern: String) {
            self.line = line
            self.pattern = TextPattern(pattern)
        }
    }

    // Order matters: a numbered adventure path volume wins over words in its campaign name,
    // and accessories named after a campaign (pawns, maps) win over the campaign's line.
    private static let titleRules = [
        Rule(.communityUse, #"Community Use"#),
        Rule(.adventurePath, #"Adventure Path #\d+"#),
        Rule(.cards, #"Adventure Card|\bCards\b|\bDeck\b"#),
        Rule(.pawns, #"\bPawns?\b"#),
        Rule(.maps, #"Flip-Mat|Flip-Tiles|Map Pack|Poster Map|Map Folio|Interactive Maps|\bMaps?\b"#),
        Rule(
            .societyScenario,
            #"Society.*(Scenario|Special|Intro)|\bScenario #?\d|Pathfinder Special|Playtest Scenario"#
        ),
        Rule(.quest, #"\bQuest\b"#),
        Rule(.bounty, #"\bBounty\b"#),
        Rule(.oneShot, #"One-Shot"#),
        Rule(.adventurePath, #"Adventure Path"#),
        Rule(.adventure, #"\bModule\b|\bAdventure\b|Beginner Box Bash"#),
        Rule(.fiction, #"Pathfinder Tales|Starfinder Tales|\bePub\b"#),
        Rule(.playerCompanion, #"Player Companion|Pathfinder Companion"#),
        Rule(.setting, #"Campaign Setting|Chronicles|Lost Omens"#),
        Rule(.rulebook, #"Roleplaying Game|Rulebook|\bCore\b|Bestiary|Alien Archive|Playtest|\bGuide\b"#)
    ]

    private static let categoryRules = [
        Rule(.rulebook, #"Rulebooks"#),
        Rule(.maps, #"Maps"#),
        Rule(.adventure, #"Adventures"#),
        Rule(.setting, #"Setting|Lost Omens"#),
        Rule(.fiction, #"Fiction|Novels"#),
        Rule(.pawns, #"Pawns"#),
        Rule(.cards, #"Cards"#)
    ]
}

/// Rules that decide the game system from the SKU, storefront brand and title.
enum GameSystemRules {
    static func gameSystem(title: String, sku: String, brand: String) -> GameSystem {
        if title.localizedCaseInsensitiveContains("Adventure Card") {
            return .cardGame
        }
        if let system = systemFromBrand(brand) ?? systemFromSKUPrefix(sku) {
            return system
        }
        if title.localizedCaseInsensitiveContains("Starfinder") {
            return isSecondEditionStarfinder(title: title, sku: sku) ? .starfinder2 : .starfinder1
        }
        if pathfinderTitle.matches(title) {
            return isSecondEditionPathfinder(title: title, sku: sku) ? .pathfinder2 : .pathfinder1
        }
        return .other
    }

    private static func systemFromSKUPrefix(_ sku: String) -> GameSystem? {
        skuPrefixes.first(where: { sku.hasPrefix($0.prefix) })?.system
    }

    /// Brands such as "Pathfinder Society 2E" or "Starfinder 1E" name the edition; plain
    /// "Pathfinder" and "Starfinder" do not, so those are left to the other rules.
    private static func systemFromBrand(_ brand: String) -> GameSystem? {
        let name = brand.lowercased()
        let isStarfinder = name.contains("starfinder")
        if name.contains("2e") {
            return isStarfinder ? .starfinder2 : .pathfinder2
        }
        if name.contains("1e") {
            return isStarfinder ? .starfinder1 : .pathfinder1
        }
        return nil
    }

    private static func isSecondEditionStarfinder(title: String, sku: String) -> Bool {
        secondEditionStarfinderTitle.matches(title) || fiveDigitStarfinderSKU.matches(sku)
    }

    private static func isSecondEditionPathfinder(title: String, sku: String) -> Bool {
        if let volume = adventurePathVolume.captures(in: title).last.flatMap({ Int($0) }) {
            return volume >= firstSecondEditionVolume
        }
        return secondEditionTitle.matches(title) || secondEditionPathfinderSKU.matches(sku)
    }

    /// Pathfinder Adventure Path #145 (Age of Ashes) was the first volume for Second Edition.
    private static let firstSecondEditionVolume = 145
    private static let skuPrefixes: [(prefix: String, system: GameSystem)] = [
        ("PZOPSS", .pathfinder1), ("PZOPFS", .pathfinder2), ("PZOSFS", .starfinder1)
    ]
    private static let pathfinderTitle = TextPattern(#"Pathfinder|GameMastery"#)
    private static let adventurePathVolume = TextPattern(#"Adventure Path #(\d+)"#)
    private static let secondEditionTitle = TextPattern(
        #"Second Edition|Remaster|PF2E|\b2E\b|Lost Omens|Bounty|One-Shot|Quest \(Series 2\)"#
    )
    private static let secondEditionPathfinderSKU = TextPattern(#"^PZO(1\d{4,}|21\d{2})(E|-|$)"#)
    private static let secondEditionStarfinderTitle = TextPattern(#"Second Edition|\(S2\)"#)
    private static let fiveDigitStarfinderSKU = TextPattern(#"^PZO2\d{4,}"#)
}
