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

    /// A zip that is only the means of delivering documents, such as the chapters of a book or a
    /// scenario with its maps: unpacked after download so the files can be opened.
    public var isUnpackedArchive: Bool { entitlement.isArchive && !isSavedElsewhere }

    /// A zip of material that is not for reading in the app, such as a community use package or a
    /// set of images: saved where the user chooses and not kept by the app.
    public var isSavedElsewhere: Bool {
        entitlement.isArchive && Self.assetPackName.matches(entitlement.displayName)
    }

    private static let assetPackName = TextPattern(
        #"Community Use|\bJPE?Gs?\b|\bPNGs?\b|\bLogos?\b|\bIcons?\b|Audiobook"#
    )
}

/// One product: all entitlements that come from the same SKU.
public struct LibraryTitle: Sendable, Equatable, Identifiable {
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
    /// The title in a form that sorts naturally with plain string comparison: `#2` before `#10`.
    public var titleSortKey: String

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
        titleSortKey = ""
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

    /// Fills in the derived search text and sort key once the item is complete.
    func withDerivedText() -> LibraryTitle {
        var copy = self
        let parts = [title, sku, classification.series, metadata.summary, classification.productLine.label,
                     classification.gameSystem.label]
            + editions.map(\.entitlement.displayName) + tags
        copy.searchText = parts.joined(separator: " ").lowercased()
        copy.titleSortKey = Self.naturalSortKey(title)
        return copy
    }

    /// Lowercases and pads every run of digits to six places.
    static func naturalSortKey(_ text: String) -> String {
        var key = ""
        var digits = ""
        for character in text.lowercased() {
            if character.isASCII, character.isNumber {
                digits.append(character)
                continue
            }
            key += padded(digits)
            digits = ""
            key.append(character)
        }
        return key + padded(digits)
    }

    private static func padded(_ digits: String) -> String {
        digits.isEmpty ? "" : String(repeating: "0", count: max(0, 6 - digits.count)) + digits
    }
}
