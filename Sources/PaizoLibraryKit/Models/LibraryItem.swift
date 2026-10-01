import Foundation

public enum EditionKind: Int, Codable, Sendable, CaseIterable {
    case singleFile
    case filePerChapter
    case liteSingleFile
    case liteFilePerChapter
    case epub
    case other

    public var label: String {
        switch self {
        case .singleFile: "Single File"
        case .filePerChapter: "File per Chapter"
        case .liteSingleFile: "Lite Single File"
        case .liteFilePerChapter: "Lite File per Chapter"
        case .epub: "ePub"
        case .other: ""
        }
    }
}

/// One entitlement shown inside its title.
public struct Edition: Sendable, Equatable, Identifiable {
    public var entitlement: Entitlement
    public var kind: EditionKind
    public var label: String

    public init(entitlement: Entitlement, kind: EditionKind, label: String) {
        self.entitlement = entitlement
        self.kind = kind
        self.label = label
    }

    public var id: String { entitlement.packageID }

    /// True when the package holds several individual files that can be fetched one by one.
    public var hasChapters: Bool { entitlement.assetCount > 1 }
}

/// One product: all entitlements that come from the same SKU.
public struct LibraryItem: Sendable, Equatable, Identifiable {
    public var id: String
    public var sku: String
    public var title: String
    public var editions: [Edition]
    public var metadata: ProductMetadata
    public var classification: Classification
    public var tags: [String]
    public var dateAdded: Date
    /// Lowercased text the search field matches against.
    public var searchText: String

    public init(id: String, sku: String, title: String, editions: [Edition]) {
        self.id = id
        self.sku = sku
        self.title = title
        self.editions = editions
        metadata = .empty
        classification = Classification()
        tags = []
        dateAdded = editions.compactMap(\.entitlement.dateGranted).max() ?? .distantPast
        searchText = ""
    }

    // Sort keys for the column view.
    public var gameSystemLabel: String { classification.gameSystem.label }
    public var productLineLabel: String { classification.productLine.label }
    public var series: String { classification.series }
    public var numberSortKey: Int { classification.number ?? Int.max }
    public var levelSortKey: Int { classification.levelRange?.lowerBound ?? Int.max }
    public var pageCount: Int { metadata.pageCount }
    public var formatsLabel: String { classification.formats.joined(separator: ", ") }
    public var tagsLabel: String { tags.joined(separator: ", ") }

    /// Fallback artwork from the entitlement itself when the storefront has no cover.
    public var fallbackImageURL: String {
        editions.lazy.compactMap(\.entitlement.productImageURLs.first).first ?? ""
    }

    func rebuildingSearchText() -> LibraryItem {
        var copy = self
        let parts = [title, sku, classification.series, metadata.summary, classification.productLine.label,
                     classification.gameSystem.label]
            + editions.map(\.entitlement.displayName) + tags
        copy.searchText = parts.joined(separator: " ").lowercased()
        return copy
    }
}
