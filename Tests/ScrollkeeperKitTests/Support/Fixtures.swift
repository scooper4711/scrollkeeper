import Foundation
@testable import ScrollkeeperKit

/// Builders for test data modeled on Paizo's responses. None of it is real account data.
enum Fixtures {
    static func entitlement(
        _ displayName: String,
        sku: String = "",
        file: String = "book.pdf",
        productName: String = ""
    ) -> Entitlement {
        var entitlement = Entitlement(packageID: "pkg-" + displayName, displayName: displayName)
        entitlement.customerID = "1001"
        entitlement.providedBySKU = sku
        entitlement.productName = productName
        entitlement.fileName = file
        entitlement.filePath = file.isEmpty ? "" : "https://bucket.example/" + file
        entitlement.assetCount = file.hasSuffix(".zip") ? 3 : 1
        return entitlement
    }

    /// A raw entitlement in Paizo's wire format.
    static func record(id: String, name: String, sku: String = "PZO1000E", file: String = "book.pdf") -> [String: Any] {
        record(RecordFields(id: id, name: name, sku: sku, file: file))
    }

    /// What a raw entitlement is built from; `updated` is Paizo's last-updated date in its own format.
    struct RecordFields {
        var id: String
        var name: String
        var sku = "PZO1000E"
        var file = "book.pdf"
        var updated = ""
    }

    static func record(_ fields: RecordFields) -> [String: Any] {
        let (id, name, sku, file) = (fields.id, fields.name, fields.sku, fields.file)
        var record = baseRecord(id: id, name: name, sku: sku, file: file)
        if !fields.updated.isEmpty {
            record["PackageDateLastUpdated"] = fields.updated
        }
        return record
    }

    private static func baseRecord(id: String, name: String, sku: String, file: String) -> [String: Any] {
        [
            "DigitalPackageID": id,
            "PackageDisplayName": name,
            "CustomerID": "1001",
            "ProvidedByProductSku": sku,
            "DateEntitlementGranted": "2024-11-08 09:45:21",
            "DigitalPackage": [
                "File": file,
                "Filepath": "https://bucket.example/" + file,
                "DisplayName": name,
                "DigitalAssets": ["asset-1"],
                "Products": [["sku": sku]]
            ]
        ]
    }

    /// Library page HTML carrying the given records, split over two chunks like the real page.
    static func libraryPageHTML(records: [[String: Any]], count: Int, tokenExpired: Bool = false) -> String {
        let properties: [String: Any] = ["entitlements": records, "count": count, "tokenExpired": tokenExpired]
        let row = "4:" + jsonString(["$", "$Lb", NSNull(), properties]) + "\n"
        let payload = "1:HL[\"/_next/static/css/app.css\",\"style\"]\n" + row
        let middle = payload.index(payload.startIndex, offsetBy: payload.count / 2)
        let chunks = [String(payload[..<middle]), String(payload[middle...])]
        let scripts = chunks.map { "<script>self.__next_f.push([1,\(jsonString($0))])</script>" }
        return "<!DOCTYPE html><html><body>" + scripts.joined() + "</body></html>"
    }

    /// The bytes of a zip archive holding the given files, made with the system's `ditto`.
    static func zipArchive(files: [String: String]) throws -> Data {
        let workspace = TemporaryDirectory()
        let source = workspace.url.appending(path: "source", directoryHint: .isDirectory)
        for (name, contents) in files {
            let file = source.appending(path: name)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try Data(contents.utf8).write(to: file)
        }
        let archive = workspace.url.appending(path: "archive.zip")
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", source.path, archive.path]
        try process.run()
        process.waitUntilExit()
        return try Data(contentsOf: archive)
    }

    static func jsonString(_ value: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    static func jsonData(_ value: Any) -> Data {
        Data(jsonString(value).utf8)
    }

    static func metadata(
        sku: String,
        brand: String = "",
        categories: [String] = [],
        summary: String = ""
    ) -> ProductMetadata {
        var metadata = ProductMetadata(sku: sku)
        metadata.name = "Product " + sku
        metadata.brand = brand
        metadata.categoryPath = categories
        metadata.summary = summary
        metadata.coverURL = "https://cdn.example/\(sku).jpg"
        return metadata
    }
}
