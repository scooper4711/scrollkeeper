import Foundation

/// What the public storefront knows about a product.
public struct ProductMetadata: Codable, Sendable, Equatable {
    public var sku: String
    public var name: String
    public var storePath: String
    public var descriptionHTML: String
    public var summary: String
    public var coverURL: String
    public var brand: String
    public var categoryPath: [String]
    public var pageCount: Int

    public init(sku: String) {
        self.sku = sku
        name = ""
        storePath = ""
        descriptionHTML = ""
        summary = ""
        coverURL = ""
        brand = ""
        categoryPath = []
        pageCount = 0
    }

    public static let empty = ProductMetadata(sku: "")

    /// True when the storefront did not know the product.
    public var isEmpty: Bool { name.isEmpty && coverURL.isEmpty && summary.isEmpty }

    public var storeURL: URL? {
        storePath.isEmpty ? nil : URL(string: "https://store.paizo.com" + storePath)
    }
}
