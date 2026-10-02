import Foundation

/// Reads product metadata from the public Paizo storefront. No sign-in is needed.
public actor StorefrontClient {
    /// The storefront limits query complexity; ten products per request fits.
    public static let batchSize = 10
    static let coverWidth = 480

    private let http: HTTPClient
    private let endpoints: PaizoEndpoints
    private var token = ""

    public init(http: HTTPClient, endpoints: PaizoEndpoints = .standard) {
        self.http = http
        self.endpoints = endpoints
    }

    /// Metadata for up to `batchSize` SKUs. SKUs the storefront does not know are left out.
    public func fetchMetadata(skus: [String]) async throws -> [ProductMetadata] {
        let response = try await sendQuery(skus: skus)
        guard response.statusCode == 401 else {
            return try decode(response, skus: skus)
        }
        token = ""
        return try decode(try await sendQuery(skus: skus), skus: skus)
    }

    private struct QueryResponse: Decodable {
        let data: SiteContainer?
    }

    private struct SiteContainer: Decodable {
        let site: [String: Lossy<ProductNode>]
    }

    private func sendQuery(skus: [String]) async throws -> HTTPResponse {
        let variables = Dictionary(uniqueKeysWithValues: skus.enumerated().map { ("s\($0.offset)", $0.element) })
        let body: [String: Any] = ["query": Self.makeQuery(count: skus.count), "variables": variables]
        var request = URLRequest(url: endpoints.storeURL("/graphql"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await storefrontToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await http.send(request)
    }

    private func decode(_ response: HTTPResponse, skus: [String]) throws -> [ProductMetadata] {
        let operation = "Loading product details"
        let valid = try response.validated(operation: operation)
        guard let site = try? JSONDecoder().decode(QueryResponse.self, from: valid.data).data?.site else {
            throw PaizoError.unexpectedResponse(operation: operation)
        }
        return skus.indices.compactMap { index in
            site["p\(index)"]?.wrapped?.metadata(requestedSKU: skus[index])
        }
    }

    /// The anonymous token the storefront embeds in its home page.
    private func storefrontToken() async throws -> String {
        if !token.isEmpty {
            return token
        }
        let operation = "Opening the Paizo store"
        let response = try await http.send(.get(endpoints.storeURL("/"))).validated(operation: operation)
        guard let found = Self.tokenPattern.captures(in: response.text).last, !found.isEmpty else {
            throw PaizoError.unexpectedResponse(operation: operation)
        }
        token = found
        return found
    }

    static func makeQuery(count: Int) -> String {
        let variables = (0..<count).map { "$s\($0): String!" }.joined(separator: ", ")
        let products = (0..<count).map { "p\($0): product(sku: $s\($0)) { ...Details }" }.joined(separator: " ")
        return "query Products(\(variables)) { site { \(products) } } " + detailsFragment
    }

    private static let tokenPattern = TextPattern(#"graphql_token\\?"\s*:\s*\\?"([^"\\]+)"#)
    private static let detailsFragment = """
    fragment Details on Product { sku name path plainTextDescription(characterLimit: 4000) \
    brand { name } defaultImage { url(width: \(coverWidth)) } \
    categories { edges { node { breadcrumbs(depth: 5) { edges { node { name } } } } } } \
    customFields(first: 30) { edges { node { name value } } } }
    """
}

/// A GraphQL connection: `{ edges: [{ node }] }`.
struct GraphEdges<Node: Decodable>: Decodable {
    struct Edge: Decodable {
        let node: Node
    }

    let edges: [Edge]

    var nodes: [Node] { edges.map(\.node) }
}

/// The storefront's GraphQL shape for one product.
struct ProductNode: Decodable {
    struct Named: Decodable {
        let name: String?
        let value: String?
    }

    struct Image: Decodable {
        let url: String?
    }

    struct Category: Decodable {
        let breadcrumbs: GraphEdges<Named>?
    }

    let sku: String?
    let name: String?
    let path: String?
    let plainTextDescription: String?
    let brand: Named?
    let defaultImage: Image?
    let categories: GraphEdges<Category>?
    let customFields: GraphEdges<Named>?

    func metadata(requestedSKU: String) -> ProductMetadata {
        var metadata = ProductMetadata(sku: requestedSKU)
        metadata.name = name ?? ""
        metadata.storePath = path ?? ""
        metadata.summary = (plainTextDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        metadata.coverURL = defaultImage?.url ?? ""
        metadata.brand = brand?.name ?? ""
        metadata.categoryPath = categories?.nodes.first?.breadcrumbs?.nodes.compactMap(\.name) ?? []
        metadata.pageCount = Int(customField("Page Count")) ?? 0
        metadata.startingLevel = customField("Starting Level")
        let credited = customField("Author(s)")
        metadata.author = credited.isEmpty ? AuthorParser.parse(metadata.summary) : credited
        return metadata
    }

    private func customField(_ name: String) -> String {
        let value = customFields?.nodes.first(where: { $0.name == name })?.value ?? ""
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
