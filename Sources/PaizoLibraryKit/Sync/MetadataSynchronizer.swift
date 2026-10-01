import Foundation

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

    /// Metadata for every requested SKU; SKUs the storefront does not know get an empty record
    /// so they are not asked for again. Returns nothing when the storefront cannot be reached,
    /// so that the batch is tried again later.
    public func fetch(skus: [String]) async -> [ProductMetadata] {
        guard let found = try? await storefront.fetchMetadata(skus: skus) else { return [] }
        await downloadCovers(for: found)
        let known = Set(found.map(\.sku))
        return found + skus.filter { !known.contains($0) }.map { ProductMetadata(sku: $0) }
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
