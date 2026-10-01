import Foundation

/// A file that can be requested from Paizo's download API.
public struct RemoteFile: Sendable, Equatable {
    public var displayName: String
    public var fileName: String
    public var filePath: String
    public var customerID: String

    public init(displayName: String, fileName: String, filePath: String, customerID: String) {
        self.displayName = displayName
        self.fileName = fileName
        self.filePath = filePath
        self.customerID = customerID
    }

    public init(entitlement: Entitlement) {
        self.init(
            displayName: entitlement.displayName,
            fileName: entitlement.fileName,
            filePath: entitlement.filePath,
            customerID: entitlement.customerID
        )
    }

    public var isAvailable: Bool { !fileName.isEmpty && !filePath.isEmpty }

    var isLegacyStorage: Bool { filePath.contains(Entitlement.legacyStorageMarker) }

    /// The storage key the download API expects: the path inside the old bucket, or the file name.
    var downloadKey: String {
        guard let marker = filePath.range(of: Entitlement.legacyStorageMarker) else {
            return fileName.removingPercentEncoding ?? fileName
        }
        let path = filePath[marker.upperBound...].split(separator: "?").first.map(String.init) ?? ""
        return path.removingPercentEncoding ?? path
    }
}

/// Reads the library listing and requests downloads from Paizo's library app.
public struct LibraryCatalogClient: Sendable {
    private let http: HTTPClient
    private let session: PaizoSession
    private let parser = FlightPayloadParser()

    public init(http: HTTPClient, session: PaizoSession) {
        self.http = http
        self.session = session
    }

    /// One page of fifty entitlements, newest first. Pages start at 1.
    public func fetchPage(_ number: Int) async throws -> LibraryPage {
        let page = try await requestPage(number, token: session.customerToken())
        guard page.tokenExpired else { return page }
        let retried = try await requestPage(number, token: session.renewedCustomerToken())
        guard !retried.tokenExpired else { throw PaizoError.tokenExpired }
        return retried
    }

    /// A signed URL that can be downloaded without further authentication.
    public func signedDownloadURL(for file: RemoteFile) async throws -> URL {
        guard file.isAvailable else { throw PaizoError.fileUnavailable(name: file.displayName) }
        let operation = "Requesting the download"
        let token = try await session.customerToken()
        let ticket = try await requestTicket(for: file, token: token)
        let url = try await appURL("/api/library/download/\(ticket)")
        let response = try await http.send(.get(url)).validated(operation: operation)
        guard let answer = try? JSONDecoder().decode(DownloadResponse.self, from: response.data),
              let signed = answer.data.flatMap({ URL(string: $0.value) })
        else { throw PaizoError.unexpectedResponse(operation: operation) }
        return signed
    }

    private struct DownloadResponse: Decodable {
        let data: FlexibleString?
        let error: String?
    }

    private func requestPage(_ number: Int, token: String) async throws -> LibraryPage {
        let query = [URLQueryItem(name: "token", value: token), URLQueryItem(name: "page", value: String(number))]
        let url = await session.currentEndpoints().appURL("/customer-library", query: query)
        let response = try await http.send(.get(url)).validated(operation: "Loading library page \(number)")
        return try parser.parsePage(html: response.text)
    }

    private func requestTicket(for file: RemoteFile, token: String) async throws -> String {
        let operation = "Requesting the download"
        // The order of these fields matters: Paizo reads them by position.
        let fields = [
            (name: "key", value: file.downloadKey),
            (name: "legacy", value: file.isLegacyStorage ? "true" : "false"),
            (name: "token", value: token),
            (name: "customer", value: file.customerID)
        ]
        let url = await session.currentEndpoints().appURL("/api/library/download")
        let response = try await http.send(.postJSON(url, orderedFields: fields)).validated(operation: operation)
        guard let answer = try? JSONDecoder().decode(DownloadResponse.self, from: response.data) else {
            throw PaizoError.unexpectedResponse(operation: operation)
        }
        if let reason = answer.error, !reason.isEmpty {
            throw PaizoError.downloadRefused(reason: reason)
        }
        guard let ticket = answer.data?.value, !ticket.isEmpty else {
            throw PaizoError.unexpectedResponse(operation: operation)
        }
        return ticket
    }

    private func appURL(_ path: String) async throws -> URL {
        let token = try await session.customerToken()
        return await session.currentEndpoints().appURL(path, query: [URLQueryItem(name: "token", value: token)])
    }
}
