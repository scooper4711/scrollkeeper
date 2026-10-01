import Foundation

/// `HTTPClient` backed by a `URLSession` that keeps Paizo's session cookies in memory.
public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(configuration: URLSessionConfiguration = URLSessionHTTPClient.makeConfiguration()) {
        session = URLSession(configuration: configuration)
    }

    /// An in-memory configuration: cookies and caches are not written to disk.
    public static func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        // Tokens and library pages must never be answered from a cache.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 180
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        return configuration
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let (data, response) = try await session.data(for: request)
        return HTTPResponse(data: data, statusCode: statusCode(of: response), finalURL: response.url)
    }

    public func download(_ request: URLRequest, to destination: URL, progress: @escaping ProgressHandler) async throws {
        let observer = DownloadProgressObserver(progress: progress)
        let (temporary, response) = try await session.download(for: request, delegate: observer)
        let status = statusCode(of: response)
        guard (200..<300).contains(status) else {
            try? FileManager.default.removeItem(at: temporary)
            throw PaizoError.http(operation: "Downloading the file", status: status)
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        _ = try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        progress(1)
    }

    private func statusCode(of response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/18.0 Safari/605.1.15 PaizoLibraryManager/1.0"
}

/// Reports the fraction completed of one download task.
///
/// The async download API does not call the byte-count delegate methods, so this observes the
/// task's `Progress` instead. `@unchecked Sendable`: the observation is written once, when the
/// session creates the task, and only read again when the observer is released.
private final class DownloadProgressObserver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let progress: ProgressHandler
    private var observation: NSKeyValueObservation?

    init(progress: @escaping ProgressHandler) {
        self.progress = progress
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let progress = progress
        observation = task.progress.observe(\.fractionCompleted) { taskProgress, _ in
            progress(taskProgress.fractionCompleted)
        }
    }
}
