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

    public func makeItems(from snapshot: CatalogSnapshot) -> [LibraryTitle] {
        makeItems(from: snapshot, reusing: [])
    }

    /// Builds the titles, reusing those in `previous` whose entitlements, metadata and tags are
    /// unchanged. Classifying is the costly part, so this keeps rebuilds during a sync cheap.
    public func makeItems(from snapshot: CatalogSnapshot, reusing previous: [LibraryTitle]) -> [LibraryTitle] {
        var order: [String] = []
        var groups: [String: [Entitlement]] = [:]
        for entitlement in snapshot.entitlements {
            let key = entitlement.resolvedSKU.isEmpty ? entitlement.packageID : entitlement.resolvedSKU
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(entitlement)
        }
        let reusable = Dictionary(previous.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return order.map { key in
            let group = GroupInput(id: key, entitlements: groups[key] ?? [], snapshot: snapshot)
            if let existing = reusable[key], group.matches(existing) {
                return existing
            }
            return makeItem(group)
        }
    }

    /// Everything one title is built from.
    private struct GroupInput {
        let id: String
        let entitlements: [Entitlement]
        let sku: String
        let metadata: ProductMetadata
        let tags: [String]

        init(id: String, entitlements: [Entitlement], snapshot: CatalogSnapshot) {
            self.id = id
            self.entitlements = entitlements
            sku = entitlements.first?.resolvedSKU ?? ""
            metadata = snapshot.metadata[sku] ?? .empty
            tags = snapshot.tags[id] ?? []
        }

        func matches(_ item: LibraryTitle) -> Bool {
            guard item.metadata == metadata, item.tags == tags, item.editions.count == entitlements.count else {
                return false
            }
            let previous = item.editions.map(\.entitlement).sorted { $0.packageID < $1.packageID }
            return previous == entitlements.sorted { $0.packageID < $1.packageID }
        }
    }

    private func makeItem(_ group: GroupInput) -> LibraryTitle {
        let title = makeTitle(group.entitlements)
        var item = LibraryTitle(
            id: group.id, sku: group.sku, title: title, editions: makeEditions(group.entitlements, title: title)
        )
        item.metadata = group.metadata
        item.tags = group.tags
        let extensions = Set(group.entitlements.map(\.fileExtension).filter { !$0.isEmpty })
        item.classification = classifier.classify(
            ClassificationInput(
                title: title, sku: group.sku, metadata: item.metadata,
                formats: extensions.sorted().map { $0.uppercased() }
            )
        )
        return item.withDerivedText()
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
        // A title ending in a parenthesis leaves its closing parenthesis at the front of the remainder.
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
