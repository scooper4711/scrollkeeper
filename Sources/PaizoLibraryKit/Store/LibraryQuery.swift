import Foundation

/// The part of the library the sidebar selects.
public enum LibraryScope: Hashable, Sendable {
    case all
    case downloaded
    case productLine(ProductLine)
    case gameSystem(GameSystem)
    case tag(String)
}

/// What the user is looking for: a sidebar scope, filters and search words.
public struct LibraryQuery: Equatable, Sendable {
    public var scope = LibraryScope.all
    public var searchText = ""
    public var gameSystem: GameSystem?
    public var productLine: ProductLine?
    /// Uppercased file format such as `PDF`; empty for any.
    public var format = ""
    /// Keep titles written for this character level.
    public var level: Int?
    public var downloadedOnly = false

    public init() {}

    /// True when a filter besides the sidebar scope and search text is set.
    public var hasFilters: Bool {
        gameSystem != nil || productLine != nil || !format.isEmpty || level != nil || downloadedOnly
    }

    public mutating func clearFilters() {
        gameSystem = nil
        productLine = nil
        format = ""
        level = nil
        downloadedOnly = false
    }

    public func filter(_ items: [LibraryTitle], downloadedIDs: Set<String>) -> [LibraryTitle] {
        let words = searchText.lowercased().split(separator: " ").map(String.init)
        return items.filter { item in
            let isDownloaded = downloadedIDs.contains(item.id)
            return matchesScope(item, isDownloaded: isDownloaded)
                && matchesFilters(item, isDownloaded: isDownloaded)
                && words.allSatisfy(item.searchText.contains)
        }
    }

    private func matchesScope(_ item: LibraryTitle, isDownloaded: Bool) -> Bool {
        switch scope {
        case .all: true
        case .downloaded: isDownloaded
        case let .productLine(line): item.classification.productLine == line
        case let .gameSystem(system): item.classification.gameSystem == system
        case let .tag(tag): item.tags.contains(tag)
        }
    }

    private func matchesFilters(_ item: LibraryTitle, isDownloaded: Bool) -> Bool {
        let classification = item.classification
        return (gameSystem == nil || classification.gameSystem == gameSystem)
            && (productLine == nil || classification.productLine == productLine)
            && (format.isEmpty || classification.formats.contains(format))
            && (level.map { classification.levelRange?.contains($0) == true } ?? true)
            && (!downloadedOnly || isDownloaded)
    }
}

/// Counts shown beside the sidebar entries, and the values the filter menus offer.
public struct LibraryFacets: Equatable, Sendable {
    public var total = 0
    public var downloaded = 0
    public var productLines: [ProductLine: Int] = [:]
    public var gameSystems: [GameSystem: Int] = [:]
    public var tags: [String: Int] = [:]
    public var formats: [String] = []

    public init() {}

    public init(items: [LibraryTitle], downloadedIDs: Set<String>) {
        total = items.count
        downloaded = items.filter { downloadedIDs.contains($0.id) }.count
        var formatSet = Set<String>()
        for item in items {
            productLines[item.classification.productLine, default: 0] += 1
            gameSystems[item.classification.gameSystem, default: 0] += 1
            item.tags.forEach { tags[$0, default: 0] += 1 }
            formatSet.formUnion(item.classification.formats)
        }
        formats = formatSet.sorted()
    }

    public var sortedTags: [String] {
        tags.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public func count(for scope: LibraryScope) -> Int {
        switch scope {
        case .all: total
        case .downloaded: downloaded
        case let .productLine(line): productLines[line] ?? 0
        case let .gameSystem(system): gameSystems[system] ?? 0
        case let .tag(tag): tags[tag] ?? 0
        }
    }
}
