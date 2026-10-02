import Foundation

/// A string that Paizo sometimes sends as a number.
struct FlexibleString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            value = text
        } else if let number = try? container.decode(Int.self) {
            value = String(number)
        } else {
            value = ""
        }
    }
}

/// An array element that decodes to nothing instead of failing the whole array.
struct Lossy<Wrapped: Decodable>: Decodable {
    let wrapped: Wrapped?

    init(from decoder: Decoder) throws {
        wrapped = try? Wrapped(from: decoder)
    }
}

struct ProductRecord: Decodable {
    let name: String?
    let sku: String?
    let images: [String]?
}

struct ProductReferenceRecord: Decodable {
    let sku: String?
}

struct PackageRecord: Decodable {
    let file: String?
    let filepath: String?
    let displayName: String?
    let digitalAssets: [FlexibleString]?
    let products: [ProductReferenceRecord]?
    let dateLastUpdated: String?

    enum CodingKeys: String, CodingKey {
        case file = "File"
        case filepath = "Filepath"
        case displayName = "DisplayName"
        case digitalAssets = "DigitalAssets"
        case products = "Products"
        case dateLastUpdated = "DateLastUpdated"
    }
}

/// The wire format of an entitlement in Paizo's library data.
struct EntitlementRecord: Decodable {
    let packageID: FlexibleString
    let displayName: String?
    let customerID: FlexibleString?
    let providedBySKU: String?
    let dateGranted: String?
    let dateUpdated: String?
    let categoryPath: [String]?
    let product: ProductRecord?
    let package: PackageRecord?

    enum CodingKeys: String, CodingKey {
        case packageID = "DigitalPackageID"
        case displayName = "PackageDisplayName"
        case customerID = "CustomerID"
        case providedBySKU = "ProvidedByProductSku"
        case dateGranted = "DateEntitlementGranted"
        case dateUpdated = "PackageDateLastUpdated"
        case categoryPath = "CategoryPath"
        case product = "Product"
        case package = "DigitalPackage"
    }

    var entitlement: Entitlement {
        var result = Entitlement(packageID: packageID.value, displayName: displayName ?? package?.displayName ?? "")
        result.customerID = customerID?.value ?? ""
        result.providedBySKU = providedBySKU ?? ""
        result.productSKUs = ([product?.sku] + (package?.products ?? []).map(\.sku)).compactMap { $0 }
        result.productName = product?.name ?? ""
        result.productImageURLs = product?.images ?? []
        result.fileName = package?.file ?? ""
        result.filePath = package?.filepath ?? ""
        result.assetCount = package?.digitalAssets?.count ?? 0
        result.categoryPath = categoryPath ?? []
        result.dateGranted = dateGranted.flatMap(PaizoDateParser.parse)
        result.dateUpdated = (dateUpdated ?? package?.dateLastUpdated).flatMap(PaizoDateParser.parse)
        return result
    }
}

/// The wire format of the single-entitlement lookup, of which only the package is read.
struct FileStatusRecord: Decodable {
    let data: PackageHolderRecord?
}

struct PackageHolderRecord: Decodable {
    let package: PackageRecord?

    enum CodingKeys: String, CodingKey {
        case package = "DigitalPackage"
    }
}
