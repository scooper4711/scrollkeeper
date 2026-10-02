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

/// What Paizo currently holds for one edition: when its file last changed and where it is.
public struct FileStatus: Sendable, Equatable {
    public var packageID: String
    public var dateUpdated: Date?
    public var fileName: String
    public var filePath: String

    public init(packageID: String, dateUpdated: Date?, fileName: String, filePath: String) {
        self.packageID = packageID
        self.dateUpdated = dateUpdated
        self.fileName = fileName
        self.filePath = filePath
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
        let token = try await session.customerToken()
        let page = try await requestPage(number, token: token)
        guard page.tokenExpired else { return page }
        let retried = try await requestPage(number, token: session.renewedCustomerToken(replacing: token))
        guard !retried.tokenExpired else { throw PaizoError.tokenExpired }
        return retried
    }

    /// A signed URL that can be downloaded without further authentication. Paizo answers with a
    /// server error when the token has lapsed, so a failed request is tried once more with a
    /// renewed token.
    public func signedDownloadURL(for file: RemoteFile) async throws -> URL {
        guard file.isAvailable else { throw PaizoError.fileUnavailable(name: file.displayName) }
        let token = try await session.customerToken()
        do {
            return try await requestSignedURL(for: file, token: token)
        } catch PaizoError.http {
            return try await requestSignedURL(for: file, token: session.renewedCustomerToken(replacing: token))
        }
    }

    /// The current state of one edition's file. This costs Paizo far less than a library page.
    /// A failed request is tried once more with a renewed token, as for downloads.
    public func fetchFileStatus(packageID: String) async throws -> FileStatus {
        let token = try await session.customerToken()
        do {
            return try await requestFileStatus(packageID: packageID, token: token)
        } catch PaizoError.http {
            let renewed = try await session.renewedCustomerToken(replacing: token)
            return try await requestFileStatus(packageID: packageID, token: renewed)
        }
    }

    private func requestFileStatus(packageID: String, token: String) async throws -> FileStatus {
        let operation = "Checking \(packageID) for an update"
        let url = await session.currentEndpoints().appURL(
            "/api/library/entitlement/customer/\(packageID)", query: [URLQueryItem(name: "token", value: token)]
        )
        let response = try await http.send(.get(url)).validated(operation: operation)
        guard let answer = try? JSONDecoder().decode(FileStatusRecord.self, from: response.data),
              let package = answer.data?.package
        else { throw PaizoError.unexpectedResponse(operation: operation) }
        return FileStatus(
            packageID: packageID,
            dateUpdated: package.dateLastUpdated.flatMap(PaizoDateParser.parse),
            fileName: package.file ?? "",
            filePath: package.filepath ?? ""
        )
    }

    private func requestSignedURL(for file: RemoteFile, token: String) async throws -> URL {
        let operation = "Requesting the download link"
        let ticket = try await requestTicket(for: file, token: token)
        let url = await session.currentEndpoints().appURL(
            "/api/library/download/\(ticket)", query: [URLQueryItem(name: "token", value: token)]
        )
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
        let operation = "Requesting the download ticket"
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
}
