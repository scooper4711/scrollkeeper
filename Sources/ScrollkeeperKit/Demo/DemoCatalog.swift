import Foundation

/// An invented library for demo mode: enough variety to show every part of the app, with no real products or
/// account. Each edition names the PDF it downloads from `Demo/Files` (written by tabletop-kit's demo library), so
/// the other Tableside Toolkit apps can be tried with it; a file the folder doesn't have downloads as a one-page PDF.
enum DemoCatalog {
    struct Title {
        let sku: String
        let name: String
        /// Edition suffix and file name, such as `("PDF - Single File", "rules.pdf")`.
        let editions: [(suffix: String, file: String)]
        let brand: String
        let category: [String]
        let summary: String
        var pages = 0
        var startingLevel = ""
    }

    static let customerID = "100001"

    static let titles: [Title] = rulebooks + adventures + organizedPlay + accessories + toolkitProducts

    /// The entitlements of the library in Paizo's wire format.
    static var records: [[String: Any]] {
        titles.enumerated().flatMap { index, title in
            title.editions.indices.map { record(title, edition: $0, day: index + 1) }
        }
    }

    /// The storefront's description of a product, or nil when the SKU is not in the demo.
    static func product(sku: String) -> [String: Any]? {
        guard let title = titles.first(where: { $0.sku == sku }) else { return nil }
        var fields: [[String: Any]] = []
        if title.pages > 0 {
            fields.append(["node": ["name": "Page Count", "value": String(title.pages)]])
        }
        if !title.startingLevel.isEmpty {
            fields.append(["node": ["name": "Starting Level", "value": title.startingLevel]])
        }
        return [
            "sku": title.sku,
            "name": title.name,
            "path": "/demo/\(title.sku.lowercased())/",
            "plainTextDescription": title.summary,
            "brand": ["name": title.brand],
            "defaultImage": ["url": "https://\(DemoFiles.coversHost)/\(title.sku).jpg"],
            "categories": ["edges": [["node": ["breadcrumbs": ["edges": breadcrumbs(title)]]]]],
            "customFields": ["edges": fields]
        ]
    }

    private static func breadcrumbs(_ title: Title) -> [[String: Any]] {
        title.category.map { ["node": ["name": $0]] }
    }

    private static func record(_ title: Title, edition index: Int, day: Int) -> [String: Any] {
        let edition = title.editions[index]
        let name = edition.suffix.isEmpty ? title.name : "\(title.name) \(edition.suffix)"
        return [
            "DigitalPackageID": "demo-\(title.sku)-\(index)",
            "PackageDisplayName": name,
            "CustomerID": customerID,
            "ProvidedByProductSku": title.sku,
            "DateEntitlementGranted": String(format: "2026-03-%02d 09:00:00", min(day, 28)),
            "Product": ["name": title.name, "sku": title.sku, "images": [String]()],
            "DigitalPackage": [
                "File": edition.file,
                "Filepath": DemoFiles.address(of: edition.file),
                "DisplayName": name,
                "DigitalAssets": ["asset-\(title.sku)-\(index)"],
                "Products": [["sku": title.sku]]
            ]
        ]
    }

    private static let both = [(suffix: "PDF - Single File", file: "rulebook.pdf"), (suffix: "ePub", file: "book.epub")]

    /// One PDF edition that downloads `file`.
    private static func pdf(_ file: String) -> [(suffix: String, file: String)] {
        [(suffix: "PDF", file: file)]
    }

    private static let rulebooks = [
        Title(sku: "DEMO1001E", name: "Sample Player Rulebook", editions: both, brand: "Pathfinder 2E",
              category: ["Demo", "Rulebooks"], summary: "Everything a player needs to build a hero.", pages: 320),
        Title(sku: "DEMO1002E", name: "Sample Game Master Rulebook", editions: both, brand: "Pathfinder 2E",
              category: ["Demo", "Rulebooks"], summary: "Advice, tools and treasure for running the game.", pages: 256),
        Title(sku: "DEMO1003E", name: "Sample Creature Rulebook", editions: pdf("rulebook.pdf"), brand: "Pathfinder 2E",
              category: ["Demo", "Rulebooks"], summary: "Four hundred creatures to challenge any party.", pages: 376),
        Title(sku: "DEMO2001E", name: "Sample Starship Rulebook", editions: pdf("rulebook.pdf"), brand: "Starfinder 2E",
              category: ["Demo", "Rulebooks"], summary: "Build ships and fly them into danger.", pages: 224),
        Title(sku: "DEMO2002E", name: "Sample Galaxy Rulebook", editions: pdf("rulebook.pdf"), brand: "Starfinder 2E",
              category: ["Demo", "Rulebooks"], summary: "A guide to the worlds beyond the homeworld.", pages: 240)
    ]

    private static let adventures = [
        Title(sku: "DEMO3001E", name: "Sample Adventure Path #1: The First Step (Demo Road 1 of 3)",
              editions: pdf("adventure.pdf"),
              brand: "Pathfinder 2E", category: ["Demo", "Adventures"],
              summary: "The road begins.\nWritten by Alex Example.", pages: 96, startingLevel: "1-4"),
        Title(sku: "DEMO3002E", name: "Sample Adventure Path #2: The Long Climb (Demo Road 2 of 3)",
              editions: pdf("adventure.pdf"),
              brand: "Pathfinder 2E", category: ["Demo", "Adventures"],
              summary: "The road rises.\nWritten by Blake Example.", pages: 96, startingLevel: "5-7"),
        Title(sku: "DEMO3003E", name: "Sample Adventure Path #3: The Last Gate (Demo Road 3 of 3)",
              editions: pdf("adventure.pdf"),
              brand: "Pathfinder 2E", category: ["Demo", "Adventures"],
              summary: "The road ends.\nWritten by Casey Example.", pages: 96, startingLevel: "8-10"),
        Title(sku: "DEMO3101E", name: "Sample Adventure: The Lighthouse",
              editions: pdf("adventure.pdf"), brand: "Pathfinder 2E",
              category: ["Demo", "Adventures"], summary: "A one-night mystery for 3rd-level characters.", pages: 64)
    ]

    private static let organizedPlay = [
        Title(sku: "DEMO4001E", name: "Sample Society Scenario #1-01: Opening Night", editions: pdf("scenario.pdf"),
              brand: "Pathfinder Society 2E", category: ["Demo", "Organized Play"],
              summary: "A scenario for 1st-2nd level characters.\nWritten by Devon Example."),
        Title(sku: "DEMO4002E", name: "Sample Society Scenario #1-02: The Second Act", editions: pdf("scenario.pdf"),
              brand: "Pathfinder Society 2E", category: ["Demo", "Organized Play"],
              summary: "A scenario for 3rd-4th level characters.\nWritten by Emery Example."),
        Title(sku: "DEMO4003E", name: "Sample Society Scenario #2-01: A New Season", editions: pdf("scenario.pdf"),
              brand: "Starfinder Society 2E", category: ["Demo", "Organized Play"],
              summary: "A scenario for 1st-2nd level characters.\nWritten by Finley Example."),
        Title(sku: "DEMO4101E", name: "Sample Bounty #1: The Missing Cat",
              editions: pdf("scenario.pdf"), brand: "Pathfinder 2E",
              category: ["Demo", "Organized Play"], summary: "A short job for 1st-level characters.")
    ]

    private static let accessories = [
        Title(sku: "DEMO5001E", name: "Sample Battle Map: Forest Trails",
              editions: pdf("map-forest.pdf"), brand: "Pathfinder",
              category: ["Demo", "Maps"], summary: "A 24-by-30-inch battle map of woodland paths."),
        Title(sku: "DEMO5002E", name: "Sample Battle Map: Starship Decks",
              editions: pdf("map-starship.pdf"), brand: "Starfinder",
              category: ["Demo", "Maps"], summary: "A 24-by-30-inch battle map of corridors and bays."),
        Title(sku: "DEMO6001E", name: "Sample Tales: The Quiet Harbor",
              editions: [(suffix: "ePub", file: "novel.epub")], brand: "Pathfinder",
              category: ["Demo", "Fiction"], summary: "A novel of intrigue.", pages: 380)
    ]

    /// The demo PDFs the other toolkit apps read: pawns, tokens and cards for Pawn Shop, Turnkeeper and Field
    /// Guide, and Field Guide's sample sourcebook, which it recognizes by this title.
    private static let toolkitProducts = [
        Title(sku: "DEMO7001E", name: "Sample Bestiary Pawn Collection", editions: pdf("pawn-collection.pdf"),
              brand: "Pathfinder 2E", category: ["Demo", "Pawns"], summary: "Twelve monsters as pawns."),
        Title(sku: "DEMO7002E", name: "Sample Iconic Heroes Pawn Collection", editions: pdf("hero-pawns.pdf"),
              brand: "Pathfinder 2E", category: ["Demo", "Pawns"],
              summary: "The Iconics as pawns, from Paizo's Community Use Package."),
        Title(sku: "DEMO7003E", name: "Sample Bestiary Token Set", editions: pdf("token-set.pdf"),
              brand: "Pathfinder 2E", category: ["Demo", "Pawns"], summary: "Twelve monsters as round tokens."),
        Title(sku: "DEMO7004E", name: "Sample Bestiary Battle Cards", editions: pdf("battle-cards.pdf"),
              brand: "Pathfinder 2E", category: ["Demo", "Cards"], summary: "Twelve monsters as Battle Cards."),
        Title(sku: "DEMO7005E", name: "Field Guide Sample Monster Core", editions: pdf("sample-monster-core.pdf"),
              brand: "Pathfinder 2E", category: ["Demo", "Rulebooks"],
              summary: "Monster Core stat blocks and art with placeholder lore, for Field Guide and Pluck.", pages: 40)
    ]
}
