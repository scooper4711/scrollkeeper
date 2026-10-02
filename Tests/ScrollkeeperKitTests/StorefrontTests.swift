import Foundation
@testable import ScrollkeeperKit
import Testing

@Suite struct StorefrontClientTests {
    private let paizo = FakePaizo()

    @Test func fetchesMetadataForKnownProductsOnly() async throws {
        paizo.installStorefront(products: ["PZO1E": FakePaizo.productNode(sku: "PZO1E", name: "Adventure One PDF")])
        let client = StorefrontClient(http: paizo.http)

        let metadata = try await client.fetchMetadata(skus: ["PZO1E", "PZOUNKNOWN"])

        #expect(metadata.count == 1)
        #expect(metadata[0].sku == "PZO1E")
        #expect(metadata[0].name == "Adventure One PDF")
        #expect(metadata[0].summary == "An adventure for 3rd- through 5th-level characters.")
        #expect(metadata[0].brand == "Pathfinder 2E")
        #expect(metadata[0].categoryPath == ["Pathfinder", "Adventures"])
        #expect(metadata[0].pageCount == 64)
        #expect(metadata[0].coverURL == "https://cdn.example/PZO1E.jpg")
        #expect(metadata[0].storeURL?.absoluteString == "https://store.paizo.com/pzo1e/")
    }

    @Test func takesAuthorFromTheCustomFieldOrTheSummary() async throws {
        var novel = FakePaizo.productNode(sku: "NOVEL", name: "Lord of Penance ePub")
        novel["customFields"] = ["edges": [
            ["node": ["name": "Author(s)", "value": " Richard Lee Byers "]],
            ["node": ["name": "Starting Level", "value": "10-14"]]
        ]]
        var scenario = FakePaizo.productNode(sku: "SCENARIO", name: "Scenario #6-06")
        scenario["plainTextDescription"] = "For 1st-4th level characters.\nWritten by Josh Foster\nScenario tags"
        paizo.installStorefront(products: ["NOVEL": novel, "SCENARIO": scenario])

        let metadata = try await StorefrontClient(http: paizo.http).fetchMetadata(skus: ["NOVEL", "SCENARIO"])

        #expect(metadata.map(\.author) == ["Richard Lee Byers", "Josh Foster"])
        #expect(metadata.map(\.startingLevel) == ["10-14", ""])
        #expect(metadata.map(\.pageCount) == [0, 64])
    }

    @Test func sendsAnonymousTokenAndReusesIt() async throws {
        paizo.installStorefront(products: [:])
        let client = StorefrontClient(http: paizo.http)
        _ = try await client.fetchMetadata(skus: ["A"])
        _ = try await client.fetchMetadata(skus: ["B"])

        let query = try #require(paizo.http.requests.last)
        #expect(query.value(forHTTPHeaderField: "Authorization") == "Bearer anonymous-token")
        #expect(paizo.http.count(of: "GET https://store.paizo.com/") == 1)
    }

    @Test func refreshesTokenOnceWhenRejected() async throws {
        paizo.installStorefront(products: [:])
        let attempts = Counter()
        paizo.http.on("POST https://store.paizo.com/graphql") { _ in
            let status = attempts.increment() == 1 ? 401 : 200
            return HTTPResponse(data: Fixtures.jsonData(["data": ["site": [:]]]), statusCode: status)
        }
        #expect(try await StorefrontClient(http: paizo.http).fetchMetadata(skus: ["A"]).isEmpty)
        #expect(paizo.http.count(of: "GET https://store.paizo.com/") == 2)
    }

    @Test func reportsFailures() async {
        let client = StorefrontClient(http: paizo.http)
        await #expect(throws: PaizoError.http(operation: "Opening the Paizo store", status: 404)) {
            try await client.fetchMetadata(skus: ["A"])
        }
        paizo.http.on("GET https://store.paizo.com/", text: "<html>no token here</html>")
        await #expect(throws: PaizoError.unexpectedResponse(operation: "Opening the Paizo store")) {
            try await client.fetchMetadata(skus: ["A"])
        }
        paizo.installStorefront(products: [:])
        paizo.http.on("POST https://store.paizo.com/graphql", json: ["errors": [["message": "too complex"]]])
        await #expect(throws: PaizoError.unexpectedResponse(operation: "Loading product details")) {
            try await client.fetchMetadata(skus: ["A"])
        }
    }

    @Test func queryAliasesOneProductPerVariable() {
        let query = StorefrontClient.makeQuery(count: 2)
        #expect(query.contains("query Products($s0: String!, $s1: String!)"))
        #expect(query.contains("p1: product(sku: $s1) { ...Details }"))
        #expect(query.contains("url(width: 480)"))
        #expect(query.contains("customFields(first: 30)"))
    }
}

@Suite struct PaizoErrorTests {
    @Test(arguments: [
        PaizoError.credentialsMissing, .signInRejected, .http(operation: "Loading", status: 500),
        .unexpectedResponse(operation: "Loading"), .tokenExpired, .downloadRefused(reason: "No"),
        .fileUnavailable(name: "Book")
    ])
    func everyErrorExplainsWhatFailed(error: PaizoError) {
        #expect(error.errorDescription?.contains("failed") == true)
    }

    @Test func responseHelpers() throws {
        let response = HTTPResponse(data: Data("hi".utf8), statusCode: 204)
        #expect(response.text == "hi")
        #expect(try response.validated(operation: "x").isSuccess)
        #expect(!HTTPResponse(data: Data(), statusCode: 302).isSuccess)
    }
}
