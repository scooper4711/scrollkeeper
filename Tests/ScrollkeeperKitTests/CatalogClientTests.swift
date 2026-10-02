import Foundation
@testable import ScrollkeeperKit
import Testing

@Suite struct LibraryCatalogClientTests {
    private let paizo = FakePaizo()

    private func makeClient() -> LibraryCatalogClient {
        paizo.installSignedInStore()
        let session = PaizoSession(http: paizo.http, credentials: MemoryCredentialStore(FakePaizo.account))
        return LibraryCatalogClient(http: paizo.http, session: session)
    }

    @Test func fetchesRequestedPageWithToken() async throws {
        let client = makeClient()
        paizo.installLibrary(records: (1...5).map { Fixtures.record(id: "p\($0)", name: "Book \($0)") })

        let page = try await client.fetchPage(3)
        #expect(page.entitlements.map(\.packageID) == ["p5"])
        #expect(page.totalCount == 5)
        #expect(paizo.http.count(of: "customer-library?token=\(FakePaizo.token)&page=3") == 1)
    }

    @Test func renewsTokenOnceWhenPageReportsItExpired() async throws {
        let client = makeClient()
        let attempts = Counter()
        paizo.http.on("https://app.paizo.com/customer-library") { request in
            let expired = attempts.increment() == 1
            let html = Fixtures.libraryPageHTML(records: [], count: 0, tokenExpired: expired)
            return HTTPResponse(data: Data(html.utf8), finalURL: request.url)
        }

        #expect(try await client.fetchPage(1).tokenExpired == false)
        #expect(paizo.http.count(of: "current.jwt") == 2)
    }

    @Test func failsWhenTokenStaysExpired() async {
        let client = makeClient()
        paizo.http.on(
            "https://app.paizo.com/customer-library",
            text: Fixtures.libraryPageHTML(records: [], count: 0, tokenExpired: true)
        )
        await #expect(throws: PaizoError.tokenExpired) { try await client.fetchPage(1) }
    }

    @Test func reportsHTTPFailureWithOperation() async {
        let client = makeClient()
        paizo.http.on("https://app.paizo.com/customer-library", text: "busy", status: 503)
        await #expect(throws: PaizoError.http(operation: "Loading library page 2", status: 503)) {
            try await client.fetchPage(2)
        }
    }

    @Test func signsDownloadForNewStorageByFileName() async throws {
        let client = makeClient()
        paizo.installDownloads()
        let file = RemoteFile(displayName: "Book", fileName: "abc-Book One.pdf",
                              filePath: "https://bucket.example/abc-Book%20One.pdf", customerID: "1001")

        #expect(try await client.signedDownloadURL(for: file).absoluteString == "https://s3.example/signed")
        #expect(try ticketRequestBody() == [
            "key": "abc-Book One.pdf", "legacy": "false", "token": FakePaizo.token, "customer": "1001"
        ])
        // Paizo reads the fields by position, so their order is part of the contract.
        #expect(try ticketRequestText() == """
        {"key":"abc-Book One.pdf","legacy":"false","token":"header.payload.signature","customer":"1001"}
        """)
    }

    @Test func signsDownloadForLegacyStorageByDecodedPath() async throws {
        let client = makeClient()
        paizo.installDownloads()
        let path = "https://s3.us-west-2.amazonaws.com/com.paizo.downloads.raw/PaizoPublishing%2CLLC/T/T.epub?X-Amz=1"
        let file = RemoteFile(displayName: "Tale", fileName: "T.epub", filePath: path, customerID: "1001")

        _ = try await client.signedDownloadURL(for: file)
        let body = try ticketRequestBody()
        #expect(body["key"] == "PaizoPublishing,LLC/T/T.epub")
        #expect(try ticketRequestText().hasPrefix(#"{"key":"PaizoPublishing,LLC/T/T.epub","legacy":"true","#))
        #expect(body["legacy"] == "true")
    }

    @Test func downloadRejectedForALapsedTokenIsRetriedWithARenewedOne() async throws {
        let client = makeClient()
        paizo.installDownloads()
        let attempts = Counter()
        paizo.http.on("POST https://app.paizo.com/api/library/download") { _ in
            let status = attempts.increment() == 1 ? 500 : 200
            return HTTPResponse(data: Fixtures.jsonData(["data": "ticket-1"]), statusCode: status)
        }
        let file = RemoteFile(entitlement: Fixtures.entitlement("Book"))

        #expect(try await client.signedDownloadURL(for: file).absoluteString == "https://s3.example/signed")
        #expect(attempts.current == 2)
        #expect(paizo.http.count(of: "current.jwt") == 2)
    }

    @Test func downloadThatKeepsFailingReportsTheStep() async {
        let client = makeClient()
        paizo.installDownloads()
        paizo.http.on("GET https://app.paizo.com/api/library/download/ticket-1", text: "", status: 500)
        let file = RemoteFile(entitlement: Fixtures.entitlement("Book"))

        await #expect(throws: PaizoError.http(operation: "Requesting the download link", status: 500)) {
            try await client.signedDownloadURL(for: file)
        }
    }

    @Test func refusesFilesPaizoHasNotAttached() async {
        let client = makeClient()
        let file = RemoteFile(entitlement: Fixtures.entitlement("Unreleased Scenario", file: ""))
        await #expect(throws: PaizoError.fileUnavailable(name: "Unreleased Scenario")) {
            try await client.signedDownloadURL(for: file)
        }
    }

    @Test(arguments: [
        (["error": "Not entitled"] as [String: String], PaizoError.downloadRefused(reason: "Not entitled")),
        (["data": ""], PaizoError.unexpectedResponse(operation: "Requesting the download ticket")),
        ([:], PaizoError.unexpectedResponse(operation: "Requesting the download ticket"))
    ])
    func reportsTicketProblems(answer: [String: String], expected: PaizoError) async {
        let client = makeClient()
        paizo.http.on("POST https://app.paizo.com/api/library/download", json: answer)
        let file = RemoteFile(entitlement: Fixtures.entitlement("Book"))
        await #expect(throws: expected) { try await client.signedDownloadURL(for: file) }
    }

    @Test func reportsMalformedAnswers() async {
        let client = makeClient()
        let file = RemoteFile(entitlement: Fixtures.entitlement("Book"))
        paizo.http.on("POST https://app.paizo.com/api/library/download", text: "<html>")
        await #expect(throws: PaizoError.unexpectedResponse(operation: "Requesting the download ticket")) {
            try await client.signedDownloadURL(for: file)
        }
        paizo.installDownloads()
        paizo.http.on("GET https://app.paizo.com/api/library/download/ticket-1", json: ["data": NSNull()])
        await #expect(throws: PaizoError.unexpectedResponse(operation: "Requesting the download link")) {
            try await client.signedDownloadURL(for: file)
        }
    }

    private func ticketRequestText() throws -> String {
        let request = try #require(paizo.http.requests.last(where: {
            $0.httpMethod == "POST" && $0.url?.path == "/api/library/download"
        }))
        return String(bytes: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    }

    private func ticketRequestBody() throws -> [String: String] {
        let object = try JSONSerialization.jsonObject(with: Data(try ticketRequestText().utf8))
        return object as? [String: String] ?? [:]
    }
}
