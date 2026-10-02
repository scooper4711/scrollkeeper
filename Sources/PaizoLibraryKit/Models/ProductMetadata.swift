import Foundation

/// What the public storefront knows about a product.
public struct ProductMetadata: Codable, Sendable, Equatable {
    /// Raised whenever a field is added, so that metadata stored by an older version is fetched again.
    public static let schemaVersion = 2

    public var sku: String
    public var name: String
    public var storePath: String
    public var summary: String
    public var coverURL: String
    public var brand: String
    public var categoryPath: [String]
    public var pageCount: Int
    public var author: String
    /// The storefront's "Starting Level" field, such as `10-14`.
    public var startingLevel: String

    public init(sku: String) {
        self.sku = sku
        name = ""
        storePath = ""
        summary = ""
        coverURL = ""
        brand = ""
        categoryPath = []
        pageCount = 0
        author = ""
        startingLevel = ""
    }

    /// Fields missing from data written by an older version take their empty value.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(sku: try container.decode(String.self, forKey: .sku))
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        storePath = try container.decodeIfPresent(String.self, forKey: .storePath) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        coverURL = try container.decodeIfPresent(String.self, forKey: .coverURL) ?? ""
        brand = try container.decodeIfPresent(String.self, forKey: .brand) ?? ""
        categoryPath = try container.decodeIfPresent([String].self, forKey: .categoryPath) ?? []
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount) ?? 0
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        startingLevel = try container.decodeIfPresent(String.self, forKey: .startingLevel) ?? ""
    }

    public static let empty = ProductMetadata(sku: "")

    /// True when the storefront did not know the product.
    public var isEmpty: Bool { name.isEmpty && summary.isEmpty }

    public var storeURL: URL? {
        storePath.isEmpty ? nil : URL(string: "https://store.paizo.com" + storePath)
    }
}
