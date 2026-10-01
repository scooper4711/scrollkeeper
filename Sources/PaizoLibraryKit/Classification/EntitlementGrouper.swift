import Foundation

/// The data titles are built from.
public struct CatalogSnapshot: Sendable, Equatable {
    public var entitlements: [Entitlement]
    public var metadata: [String: ProductMetadata]
    public var tags: [String: [String]]

    public init(
        entitlements: [Entitlement] = [],
        metadata: [String: ProductMetadata] = [:],
        tags: [String: [String]] = [:]
    ) {
        self.entitlements = entitlements
        self.metadata = metadata
        self.tags = tags
    }
}

/// Groups entitlements into titles by product SKU and classifies them.
public struct EntitlementGrouper: Sendable {
    private let classifier = Classifier()

    public init() {}

    public func makeItems(from snapshot: CatalogSnapshot) -> [LibraryItem] {
        var order: [String] = []
        var groups: [String: [Entitlement]] = [:]
        for entitlement in snapshot.entitlements {
            let key = entitlement.resolvedSKU.isEmpty ? entitlement.packageID : entitlement.resolvedSKU
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(entitlement)
        }
        return order.map { makeItem(id: $0, entitlements: groups[$0] ?? [], snapshot: snapshot) }
    }

    private func makeItem(id: String, entitlements: [Entitlement], snapshot: CatalogSnapshot) -> LibraryItem {
        let sku = entitlements.first?.resolvedSKU ?? ""
        let title = makeTitle(entitlements)
        var item = LibraryItem(id: id, sku: sku, title: title, editions: makeEditions(entitlements, title: title))
        item.metadata = snapshot.metadata[sku] ?? .empty
        item.tags = snapshot.tags[id] ?? []
        let formats = Set(entitlements.map(\.fileExtension).filter { !$0.isEmpty }).sorted().map { $0.uppercased() }
        item.classification = classifier.classify(
            ClassificationInput(title: title, sku: sku, metadata: item.metadata, formats: formats)
        )
        return item.rebuildingSearchText()
    }

    /// The product name when Paizo gives one, otherwise the shortest normalized entitlement name.
    private func makeTitle(_ entitlements: [Entitlement]) -> String {
        let displayTitles = entitlements.map(\.displayName).map(TitleNormalizer.baseTitle).filter { !$0.isEmpty }
        let productName = entitlements.map(\.productName).first(where: { !$0.isEmpty }) ?? ""
        let productTitle = TitleNormalizer.baseTitle(productName)
        if productTitle.isEmpty {
            return displayTitles.min(by: { $0.count < $1.count }) ?? "Untitled"
        }
        return productName.count < Self.truncatedNameLength
            ? productTitle
            : untruncated(productTitle, among: displayTitles)
    }

    /// Paizo cuts product names off at fifty characters; an entitlement name usually has the rest.
    private func untruncated(_ productTitle: String, among displayTitles: [String]) -> String {
        let key = TitleNormalizer.comparisonKey(productTitle)
        let completions = displayTitles.filter { TitleNormalizer.comparisonKey($0).hasPrefix(key) }
        return completions.min(by: { $0.count < $1.count }) ?? productTitle
    }

    private static let truncatedNameLength = 50

    private func makeEditions(_ entitlements: [Entitlement], title: String) -> [Edition] {
        entitlements
            .map { makeEdition($0, title: title) }
            .sorted { ($0.kind.rawValue, $0.label) < ($1.kind.rawValue, $1.label) }
    }

    private func makeEdition(_ entitlement: Entitlement, title: String) -> Edition {
        let kind = TitleNormalizer.editionKind(
            displayName: entitlement.displayName,
            fileExtension: entitlement.fileExtension
        )
        let remainder = distinguishingPart(of: entitlement.displayName, title: title)
        let label: String
        if kind == .other {
            label = remainder.isEmpty ? fallbackLabel(entitlement) : remainder
        } else {
            label = remainder.isEmpty ? kind.label : "\(remainder) – \(kind.label)"
        }
        return Edition(entitlement: entitlement, kind: kind, label: label)
    }

    /// What the entitlement name says beyond the title: `Dark Archive Remastered` → `Remastered`.
    /// Names are compared without punctuation, because Paizo spells the same title several ways.
    private func distinguishingPart(of displayName: String, title: String) -> String {
        let name = TitleNormalizer.baseTitle(displayName)
        let nameKey = TitleNormalizer.comparisonKey(name)
        let titleKey = TitleNormalizer.comparisonKey(title)
        if titleKey.hasPrefix(nameKey) {
            return ""
        }
        guard nameKey.hasPrefix(titleKey) else { return name }
        return tidyLabel(dropLeading(name, alphanumericCount: titleKey.unicodeScalars.count))
    }

    /// `(Download) - JPGs` → `JPGs`, `(S2)` → `S2`, `PDF - Assembled Maps` → `Assembled Maps`.
    private func tidyLabel(_ text: String) -> String {
        let separators = CharacterSet(charactersIn: " -:–")
        // A title ending in a parenthesis leaves its closing bracket at the front of the remainder.
        let remainder = String(text.drop(while: { ") -:–".contains($0) }))
        var label = Self.formatPrefix.removingMatches(in: remainder.trimmingCharacters(in: separators))
        if label.hasPrefix("("), label.hasSuffix(")"), label.filter({ $0 == "(" }).count == 1 {
            label = String(label.dropFirst().dropLast())
        }
        return label.trimmingCharacters(in: separators)
    }

    private static let formatPrefix = TextPattern(#"^(\(?download\)?|pdf)\s*-\s*"#)

    /// Drops characters from the front of `text` until `alphanumericCount` letters and digits are gone.
    private func dropLeading(_ text: String, alphanumericCount: Int) -> String {
        var remaining = alphanumericCount
        var scalars = Substring.UnicodeScalarView(text.unicodeScalars)
        while remaining > 0, let scalar = scalars.popFirst() {
            if CharacterSet.alphanumerics.contains(scalar) {
                remaining -= 1
            }
        }
        return String(scalars)
    }

    private func fallbackLabel(_ entitlement: Entitlement) -> String {
        entitlement.fileExtension.isEmpty ? "Unavailable" : entitlement.fileExtension.uppercased()
    }
}
