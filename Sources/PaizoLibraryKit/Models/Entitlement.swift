import Foundation

/// One downloadable package the account owns, as listed by the Paizo library.
public struct Entitlement: Codable, Sendable, Equatable, Identifiable {
    /// Marker in the file path of packages kept in Paizo's older storage bucket.
    public static let legacyStorageMarker = "com.paizo.downloads.raw/"

    public var packageID: String
    public var displayName: String
    public var customerID: String
    public var providedBySKU: String
    public var productSKUs: [String]
    public var productName: String
    public var productImageURLs: [String]
    public var fileName: String
    public var filePath: String
    public var assetCount: Int
    public var categoryPath: [String]
    public var dateGranted: Date?
    public var dateUpdated: Date?

    public init(packageID: String, displayName: String) {
        self.packageID = packageID
        self.displayName = displayName
        customerID = ""
        providedBySKU = ""
        productSKUs = []
        productName = ""
        productImageURLs = []
        fileName = ""
        filePath = ""
        assetCount = 0
        categoryPath = []
    }

    public var id: String { packageID }

    /// The product SKU this entitlement belongs to, or an empty string when Paizo gives none.
    public var resolvedSKU: String {
        ([providedBySKU] + productSKUs).first(where: Self.isUsableSKU) ?? ""
    }

    public var hasFile: Bool { !filePath.isEmpty && !fileName.isEmpty }

    public var isLegacyStorage: Bool { filePath.contains(Self.legacyStorageMarker) }

    /// Lowercased file extension without the dot, or an empty string.
    public var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    private static func isUsableSKU(_ sku: String) -> Bool {
        !sku.isEmpty && sku.lowercased() != "undefined"
    }
}

/// One individual file inside a package, such as a chapter.
public struct PackageAsset: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var fileType: String
    public var fileName: String
    public var filePath: String

    public init(id: String, displayName: String, fileType: String, fileName: String, filePath: String) {
        self.id = id
        self.displayName = displayName
        self.fileType = fileType
        self.fileName = fileName
        self.filePath = filePath
    }

    public var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }
}

/// One page of the library listing.
public struct LibraryPage: Sendable, Equatable {
    public var entitlements: [Entitlement]
    public var totalCount: Int
    public var tokenExpired: Bool

    public init(entitlements: [Entitlement], totalCount: Int, tokenExpired: Bool = false) {
        self.entitlements = entitlements
        self.totalCount = totalCount
        self.tokenExpired = tokenExpired
    }
}
