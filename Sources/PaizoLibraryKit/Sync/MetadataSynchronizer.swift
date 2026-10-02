import Foundation

/// A title that needs metadata, and the image to use when the storefront has no cover for it.
public struct MetadataRequest: Sendable, Equatable {
    public var sku: String
    public var fallbackImageURL: String

    public init(sku: String, fallbackImageURL: String = "") {
        self.sku = sku
        self.fallbackImageURL = fallbackImageURL
    }
}

/// Fetches storefront metadata and cover artwork for batches of SKUs.
public struct MetadataSynchronizer: Sendable {
    private let storefront: StorefrontClient
    private let http: HTTPClient
    private let covers: CoverStore

    public init(storefront: StorefrontClient, http: HTTPClient, covers: CoverStore) {
        self.storefront = storefront
        self.http = http
        self.covers = covers
    }

    /// Metadata for every requested SKU. A SKU the storefront does not know gets a record with
    /// only the fallback image, so it is not asked for again. Returns nothing when the storefront
    /// cannot be reached, so that the batch is tried again later.
    public func fetch(_ requests: [MetadataRequest]) async -> [ProductMetadata] {
        guard let found = try? await storefront.fetchMetadata(skus: requests.map(\.sku)) else { return [] }
        let bySKU = Dictionary(found.map { ($0.sku, $0) }, uniquingKeysWith: { first, _ in first })
        let metadata = requests.map { request in
            var product = bySKU[request.sku] ?? ProductMetadata(sku: request.sku)
            if product.coverURL.isEmpty {
                product.coverURL = request.fallbackImageURL
            }
            return product
        }
        await downloadCovers(for: metadata)
        return metadata
    }

    private func downloadCovers(for metadata: [ProductMetadata]) async {
        await withTaskGroup(of: Void.self) { group in
            for product in metadata where !covers.hasCover(sku: product.sku) {
                group.addTask { await downloadCover(for: product) }
            }
        }
    }

    private func downloadCover(for product: ProductMetadata) async {
        guard let url = URL(string: product.coverURL),
              let response = try? await http.send(.get(url)),
              response.isSuccess, !response.data.isEmpty
        else { return }
        covers.store(response.data, sku: product.sku)
    }
}
