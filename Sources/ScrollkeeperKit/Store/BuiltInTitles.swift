import Foundation

/// A title every library offers: its download and what the store would say about it.
public struct BuiltInTitle: Sendable {
    public let entitlement: Entitlement
    public let metadata: ProductMetadata
}

/// Free Paizo downloads that every library offers, though Paizo's library doesn't list them: they are added when the
/// library is built, never stored with what Paizo lists, and downloaded from their public address without signing in.
public enum BuiltInTitles {
    /// The prefix of a built-in title's package ID, which no package from Paizo has.
    static let packagePrefix = "builtin-"

    /// The Divine Mysteries Web Supplement: every deity's edicts, anathema and other stat lines in one table, which
    /// Field Guide reads.
    public static let webSupplementSKU = "PZO13003WS"

    public static let webSupplement: BuiltInTitle = {
        let title = "Pathfinder Lost Omens Divine Mysteries Web Supplement"
        var entitlement = Entitlement(packageID: packagePrefix + webSupplementSKU, displayName: title)
        entitlement.productName = title
        entitlement.providedBySKU = webSupplementSKU
        entitlement.productSKUs = [webSupplementSKU]
        entitlement.fileName = "PZO13003_SupplementalGodTable.pdf"
        entitlement.filePath = "https://downloads.paizo.com/PZO13003_SupplementalGodTable.pdf"
        entitlement.assetCount = 1
        var metadata = ProductMetadata(sku: webSupplementSKU)
        metadata.name = title
        metadata.brand = "Pathfinder 2E Remaster"
        metadata.categoryPath = ["Pathfinder", "Lost Omens Campaign Setting", "Digital Editions"]
        metadata.summary = "A free table of every deity's title, areas of concern, edicts, anathema and devotee "
            + "benefits, from the gods of Lost Omens Divine Mysteries to those only named in it."
        metadata.pageCount = 23
        return BuiltInTitle(entitlement: entitlement, metadata: metadata)
    }()

    /// The Gods & Magic Web Supplement: divine intercessions (boons and curses) for twenty deities, written before
    /// the remaster.
    public static let godsAndMagicSupplementSKU = "PZO9303WS"

    public static let godsAndMagicSupplement: BuiltInTitle = {
        let title = "Pathfinder Lost Omens Gods & Magic Web Supplement"
        var entitlement = Entitlement(packageID: packagePrefix + godsAndMagicSupplementSKU, displayName: title)
        entitlement.productName = title
        entitlement.providedBySKU = godsAndMagicSupplementSKU
        entitlement.productSKUs = [godsAndMagicSupplementSKU]
        entitlement.fileName = "PZO9303 Gods & Magic Web Supplement.pdf"
        entitlement.filePath = "https://paizo-images.s3-us-west-2.amazonaws.com/image/download/"
            + "PZO9303+Gods+%26+Magic+Web+Supplement.pdf"
        entitlement.assetCount = 1
        var metadata = ProductMetadata(sku: godsAndMagicSupplementSKU)
        metadata.name = title
        metadata.brand = "Pathfinder 2E"
        metadata.categoryPath = ["Pathfinder", "Lost Omens Campaign Setting", "Digital Editions"]
        metadata.summary = "Free divine intercessions, boons and curses, for twenty more deities of Lost Omens Gods "
            + "& Magic, with advice on creating new ones."
        metadata.pageCount = 10
        return BuiltInTitle(entitlement: entitlement, metadata: metadata)
    }()

    /// The titles the app adds (`LibraryEnvironment.builtInTitles`).
    public static let all = [webSupplement, godsAndMagicSupplement]

    /// True for an entitlement Scrollkeeper adds itself, rather than Paizo's library.
    public static func contains(_ entitlement: Entitlement) -> Bool {
        entitlement.packageID.hasPrefix(packagePrefix)
    }

    /// True for the SKU of a built-in title, whose metadata Paizo's store doesn't have.
    static func contains(sku: String) -> Bool {
        all.contains { $0.metadata.sku == sku }
    }
}

extension CatalogSnapshot {
    /// The snapshot with `titles` added, and their metadata where none is stored; unchanged while it lists nothing
    /// from Paizo, so a library that hasn't been read yet still reads as empty.
    func adding(_ titles: [BuiltInTitle]) -> CatalogSnapshot {
        guard !entitlements.isEmpty else { return self }
        var snapshot = self
        for title in titles where !snapshot.entitlements.contains(where: { $0.id == title.entitlement.id }) {
            snapshot.entitlements.append(title.entitlement)
            if snapshot.metadata[title.metadata.sku] == nil { snapshot.metadata[title.metadata.sku] = title.metadata }
        }
        return snapshot
    }
}
