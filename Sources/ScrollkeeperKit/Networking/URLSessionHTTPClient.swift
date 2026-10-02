import Foundation

/// `HTTPClient` backed by a `URLSession` that keeps Paizo's session cookies in memory.
public final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession
    private let resumeData = ResumeDataStore()

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
        let (temporary, status) = try await fetch(request, key: destination.path, observer: observer)
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

    /// Downloads to a temporary file. A download that was cut off earlier continues from where
    /// it stopped; when that is refused, for example because the link has expired, it starts over.
    /// A download cut off now leaves what it has so far for the next attempt.
    private func fetch(_ request: URLRequest, key: String, observer: DownloadProgressObserver) async throws
        -> (URL, Int) {
        do {
            if let partial = resumeData.take(key),
               let (temporary, response) = try? await session.download(resumeFrom: partial, delegate: observer),
               (200..<300).contains(statusCode(of: response)) {
                return (temporary, statusCode(of: response))
            }
            let (temporary, response) = try await session.download(for: request, delegate: observer)
            return (temporary, statusCode(of: response))
        } catch let error as URLError {
            if let partial = error.downloadTaskResumeData {
                resumeData.store(partial, for: key)
            }
            throw error
        }
    }

    private func statusCode(of response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
        + "(KHTML, like Gecko) Version/18.0 Safari/605.1.15 Scrollkeeper/1.0"
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

    func urlSession(_: URLSession, didCreateTask task: URLSessionTask) {
        let progress = progress
        observation = task.progress.observe(\.fractionCompleted) { taskProgress, _ in
            progress(taskProgress.fractionCompleted)
        }
    }
}

/// What interrupted downloads had received so far, by destination, so that they can continue.
/// `@unchecked Sendable`: the dictionary is guarded by `lock`.
final class ResumeDataStore: @unchecked Sendable {
    private let lock = NSLock()
    private var partials: [String: Data] = [:]

    func store(_ data: Data, for key: String) {
        lock.withLock { partials[key] = data }
    }

    /// The partial download for the key, which is then forgotten: it can be used only once.
    func take(_ key: String) -> Data? {
        lock.withLock { partials.removeValue(forKey: key) }
    }
}
