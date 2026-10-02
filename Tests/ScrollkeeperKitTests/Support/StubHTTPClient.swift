import Foundation
@testable import ScrollkeeperKit

/// An `HTTPClient` that answers from registered handlers and records what was asked.
///
/// `@unchecked Sendable`: all mutable state is guarded by `lock`.
final class StubHTTPClient: HTTPClient, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> HTTPResponse

    private let lock = NSLock()
    private var routes: [(fragment: String, handler: Handler)] = []
    private var recorded: [URLRequest] = []

    var requests: [URLRequest] { lock.withLock { recorded } }

    /// Lines of the form `GET https://host/path?query`, in the order they were sent.
    var requestLines: [String] { requests.map(Self.line) }

    /// Answers requests whose line contains `fragment`. The longest matching fragment wins;
    /// between equally long ones, the one registered last.
    func on(_ fragment: String, _ handler: @escaping Handler) {
        lock.withLock { routes.insert((fragment, handler), at: 0) }
    }

    func on(_ fragment: String, text: String, status: Int = 200) {
        on(fragment) { request in HTTPResponse(data: Data(text.utf8), statusCode: status, finalURL: request.url) }
    }

    func on(_ fragment: String, data: Data) {
        on(fragment) { request in HTTPResponse(data: data, finalURL: request.url) }
    }

    func on(_ fragment: String, json: Any, status: Int = 200) {
        on(fragment, text: Fixtures.jsonString(json), status: status)
    }

    func count(of fragment: String) -> Int {
        requestLines.filter { $0.contains(fragment) }.count
    }

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let handler = lock.withLock { () -> Handler? in
            recorded.append(request)
            let matching = routes.filter { Self.line(request).contains($0.fragment) }
            return matching.max(by: { $0.fragment.count < $1.fragment.count })?.handler
        }
        guard let handler else {
            return HTTPResponse(data: Data("not found".utf8), statusCode: 404, finalURL: request.url)
        }
        return try handler(request)
    }

    func download(_ request: URLRequest, to destination: URL, progress: @escaping ProgressHandler) async throws {
        let response = try await send(request).validated(operation: "Downloading the file")
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        progress(0.5)
        try response.data.write(to: destination)
        progress(1)
    }

    private static func line(_ request: URLRequest) -> String {
        "\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")"
    }
}

/// The in-memory credential store now lives in the library, where demo mode uses it too.
typealias MemoryCredentialStore = InMemoryCredentialStore
