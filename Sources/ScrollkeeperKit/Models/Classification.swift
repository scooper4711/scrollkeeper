import Foundation

public enum GameSystem: String, Codable, Sendable, CaseIterable, Identifiable {
    case pathfinder1
    case pathfinder2
    case starfinder1
    case starfinder2
    case cardGame
    case other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .pathfinder1: "Pathfinder 1E"
        case .pathfinder2: "Pathfinder 2E"
        case .starfinder1: "Starfinder 1E"
        case .starfinder2: "Starfinder 2E"
        case .cardGame: "Adventure Card Game"
        case .other: "Other"
        }
    }

    public var isSecondEdition: Bool { self == .pathfinder2 || self == .starfinder2 }
}

public enum ProductLine: String, Codable, Sendable, CaseIterable, Identifiable {
    case adventurePath
    case adventure
    case societyScenario
    case quest
    case bounty
    case oneShot
    case rulebook
    case setting
    case playerCompanion
    case maps
    case pawns
    case cards
    case fiction
    case communityUse
    case other

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .adventurePath: "Adventure Paths"
        case .adventure: "Adventures"
        case .societyScenario: "Society Scenarios"
        case .quest: "Quests"
        case .bounty: "Bounties"
        case .oneShot: "One-Shots"
        case .rulebook: "Rulebooks"
        case .setting: "Setting"
        case .playerCompanion: "Player Companions"
        case .maps: "Maps"
        case .pawns: "Pawns"
        case .cards: "Cards"
        case .fiction: "Fiction"
        case .communityUse: "Community Use"
        case .other: "Other"
        }
    }

    public var symbolName: String {
        switch self {
        case .adventurePath: "books.vertical"
        case .adventure: "book"
        case .societyScenario: "person.3"
        case .quest: "flag"
        case .bounty: "target"
        case .oneShot: "bolt"
        case .rulebook: "text.book.closed"
        case .setting: "globe"
        case .playerCompanion: "person.text.rectangle"
        case .maps: "map"
        case .pawns: "figure.stand"
        case .cards: "rectangle.on.rectangle"
        case .fiction: "book.pages"
        case .communityUse: "person.2.wave.2"
        case .other: "square.grid.2x2"
        }
    }
}

/// The automatic classification of a title.
public struct Classification: Sendable, Equatable {
    public var gameSystem: GameSystem
    public var productLine: ProductLine
    /// Adventure path campaign, or "Season 3" / "Year 3" for society play.
    public var series: String
    /// Adventure path volume, or scenario, quest or bounty number.
    public var number: Int?
    /// Position within an adventure path campaign, such as "2 of 6".
    public var part: String
    public var season: Int?
    public var levelRange: ClosedRange<Int>?
    /// Uppercased file formats of the title's editions, such as `["PDF", "ZIP"]`.
    public var formats: [String]

    public init(gameSystem: GameSystem = .other, productLine: ProductLine = .other) {
        self.gameSystem = gameSystem
        self.productLine = productLine
        series = ""
        part = ""
        formats = []
    }

    public var levelLabel: String {
        guard let levelRange else { return "" }
        return levelRange.lowerBound == levelRange.upperBound
            ? "\(levelRange.lowerBound)"
            : "\(levelRange.lowerBound)–\(levelRange.upperBound)"
    }
}
