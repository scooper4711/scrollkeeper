import Foundation
@testable import PaizoLibraryKit
import Testing

@Suite struct PaizoSessionTests {
    private let paizo = FakePaizo()

    private func makeSession(stored: Credentials? = FakePaizo.account, now: @escaping @Sendable () -> Date = { Date() })
        -> PaizoSession {
        PaizoSession(http: paizo.http, credentials: MemoryCredentialStore(stored), now: now)
    }

    @Test func signInPostsFormEncodedCredentials() async throws {
        paizo.installSignIn()
        try await makeSession().signIn(with: FakePaizo.account)
        #expect(paizo.http.count(of: "action=check_login") == 1)
    }

    @Test func signInRejectsWrongPassword() async {
        paizo.installSignIn()
        await #expect(throws: PaizoError.signInRejected) {
            try await makeSession().signIn(with: Credentials(email: "gamer@example.com", password: "wrong"))
        }
    }

    @Test func signInAdoptsEndpointsPublishedByTheLibraryPage() async throws {
        paizo.installSignIn()
        paizo.http.on(
            "https://store.paizo.com/library/",
            text: #"const appUrl = "https://library.example"; const appId = "abc123";"#
        )
        let session = makeSession()
        try await session.signIn(with: FakePaizo.account)

        let endpoints = await session.currentEndpoints()
        #expect(endpoints.app.absoluteString == "https://library.example")
        #expect(endpoints.appID == "abc123")
    }

    @Test func tokenIsReusedUntilItAges() async throws {
        paizo.installSignedInStore()
        let clock = Clock()
        let session = makeSession(now: { clock.now })

        #expect(try await session.customerToken() == FakePaizo.token)
        _ = try await session.customerToken()
        #expect(paizo.http.count(of: "current.jwt") == 1)

        clock.advance(by: PaizoSession.tokenLifetime + 1)
        _ = try await session.customerToken()
        #expect(paizo.http.count(of: "current.jwt") == 2)
    }

    @Test func signsInWithStoredCredentialsWhenStoreSessionIsMissing() async throws {
        paizo.installSignIn()
        let signedIn = Flag()
        paizo.http.on("POST https://store.paizo.com/login.php?action=check_login") { _ in
            signedIn.set()
            return HTTPResponse(data: Data(), finalURL: URL(string: "https://store.paizo.com/account.php"))
        }
        paizo.http.on("/customer/current.jwt") { request in
            let body = signedIn.isSet ? FakePaizo.token : "<html>Please sign in</html>"
            return HTTPResponse(data: Data(body.utf8), finalURL: request.url)
        }

        #expect(try await makeSession().customerToken() == FakePaizo.token)
    }

    @Test func tokenNeedsCredentials() async {
        paizo.http.on("/customer/current.jwt", text: "", status: 401)
        await #expect(throws: PaizoError.credentialsMissing) {
            try await makeSession(stored: nil).customerToken()
        }
    }

    @Test func tokenFailsWhenStoreNeverIssuesOne() async {
        paizo.installSignIn()
        paizo.http.on("/customer/current.jwt", text: "not a token")
        await #expect(throws: PaizoError.unexpectedResponse(operation: "Requesting the customer token")) {
            try await makeSession().customerToken()
        }
    }

    @Test func concurrentCallersShareOneRenewal() async throws {
        paizo.installSignedInStore()
        let session = makeSession()
        async let first = session.renewedCustomerToken()
        async let second = session.renewedCustomerToken()
        #expect(try await [first, second] == [FakePaizo.token, FakePaizo.token])
        #expect(paizo.http.count(of: "current.jwt") <= 2)
    }
}

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

    @Test func refusesFilesPaizoHasNotAttached() async {
        let client = makeClient()
        let file = RemoteFile(entitlement: Fixtures.entitlement("Unreleased Scenario", file: ""))
        await #expect(throws: PaizoError.fileUnavailable(name: "Unreleased Scenario")) {
            try await client.signedDownloadURL(for: file)
        }
    }

    @Test(arguments: [
        (["error": "Not entitled"] as [String: String], PaizoError.downloadRefused(reason: "Not entitled")),
        (["data": ""], PaizoError.unexpectedResponse(operation: "Requesting the download")),
        ([:], PaizoError.unexpectedResponse(operation: "Requesting the download"))
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
        await #expect(throws: PaizoError.unexpectedResponse(operation: "Requesting the download")) {
            try await client.signedDownloadURL(for: file)
        }
        paizo.installDownloads()
        paizo.http.on("GET https://app.paizo.com/api/library/download/ticket-1", json: ["data": NSNull()])
        await #expect(throws: PaizoError.unexpectedResponse(operation: "Requesting the download")) {
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
