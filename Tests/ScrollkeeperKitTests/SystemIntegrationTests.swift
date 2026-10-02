import Foundation
@testable import ScrollkeeperKit
import Testing

/// Answers every request made through a session configured with this protocol class.
final class StubURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool { true }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let status = url.path.contains("missing") ? 404 : 200
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: [:])
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Data("body of \(url.lastPathComponent)".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        // Nothing to cancel: startLoading answers at once.
    }
}

@Suite struct URLSessionHTTPClientTests {
    private let directory = TemporaryDirectory()
    private let ignoringProgress: ProgressHandler = { _ in
        // Progress is not what these tests check.
    }

    private func makeClient() -> URLSessionHTTPClient {
        let configuration = URLSessionHTTPClient.makeConfiguration()
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSessionHTTPClient(configuration: configuration)
    }

    private func request(_ path: String) throws -> URLRequest {
        URLRequest(url: try #require(URL(string: "https://stub.example/" + path)))
    }

    @Test func sendReturnsBodyStatusAndURL() async throws {
        let response = try await makeClient().send(request("page.html"))
        #expect(response.text == "body of page.html")
        #expect(response.statusCode == 200)
        #expect(response.finalURL?.lastPathComponent == "page.html")
    }

    @Test func downloadMovesFileIntoPlaceAndReportsCompletion() async throws {
        let destination = directory.url.appending(path: "nested/book.pdf")
        let finished = Flag()
        try Data("old".utf8).write(to: directory.url.appending(path: "placeholder"))

        try await makeClient().download(request("book.pdf"), to: destination) { fraction in
            if fraction == 1 { finished.set() }
        }
        try await makeClient().download(request("book.pdf"), to: destination, progress: ignoringProgress)

        #expect(try String(contentsOf: destination, encoding: .utf8) == "body of book.pdf")
        #expect(finished.isSet)
    }

    @Test func downloadFailsOnErrorStatusWithoutLeavingAFile() async throws {
        let destination = directory.url.appending(path: "missing.pdf")
        await #expect(throws: PaizoError.http(operation: "Downloading the file", status: 404)) {
            try await makeClient().download(request("missing.pdf"), to: destination, progress: ignoringProgress)
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test func configurationKeepsCookiesInMemoryAndIdentifiesTheApp() {
        let configuration = URLSessionHTTPClient.makeConfiguration()
        let agent = configuration.httpAdditionalHeaders?["User-Agent"] as? String
        #expect(agent?.contains("Scrollkeeper") == true)
        #expect(configuration.httpCookieAcceptPolicy == .always)
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
    }
}

@Suite struct ResumeDataStoreTests {
    @Test func partialDownloadIsHandedOutOnce() {
        let store = ResumeDataStore()
        #expect(store.take("/tmp/book.pdf") == nil)

        store.store(Data("partial".utf8), for: "/tmp/book.pdf")
        #expect(store.take("/tmp/other.pdf") == nil)
        #expect(store.take("/tmp/book.pdf") == Data("partial".utf8))
        #expect(store.take("/tmp/book.pdf") == nil)
    }
}

@Suite struct KeychainCredentialStoreTests {
    @Test func savesReplacesAndDeletesTheAccount() throws {
        let store = KeychainCredentialStore(server: "test-\(UUID().uuidString).paizo-library-manager.invalid")
        defer { try? store.delete() }
        #expect(store.load() == nil)

        try store.save(Credentials(email: "first@example.com", password: "one"))
        try store.save(Credentials(email: "second@example.com", password: "tw\u{f6}"))
        #expect(store.load() == Credentials(email: "second@example.com", password: "tw\u{f6}"))

        try store.delete()
        try store.delete()
        #expect(store.load() == nil)
    }

    @Test func keychainErrorsNameTheOperation() {
        let error = KeychainError(operation: "Saving the Paizo password to the Keychain", status: errSecDuplicateItem)
        #expect(error.errorDescription?.hasPrefix("Saving the Paizo password to the Keychain failed: ") == true)
    }

    @Test func credentialsCompleteness() {
        #expect(Credentials(email: "a@b.c", password: "x").isComplete)
        #expect(!Credentials(email: "", password: "x").isComplete)
    }
}
