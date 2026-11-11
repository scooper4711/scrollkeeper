import Foundation

/// Stands in for Paizo's store and library in demo mode: an invented library, instant sign-in and unhurried
/// downloads of real demo PDFs (`DemoFiles`). The app's UI tests run against it, and it lets the app be shown, and
/// the toolkit's apps tried together, without a real account. Only the free titles every library has, and their
/// covers, download from outside, from Paizo's public addresses, as in a real library.
public struct DemoHTTPClient: HTTPClient {
    /// How long each download takes, so that progress, waiting and canceling can be seen.
    private let downloadDuration: TimeInterval
    /// Where requests to addresses outside the demo go: the free titles' files on `downloads.paizo.com`, and their
    /// covers.
    private let outside: HTTPClient
    /// The hosts of the free titles' covers, which come from outside like their files (library-manager 13.6).
    private static let outsideHosts = Set(BuiltInTitles.all.compactMap { URL(string: $0.metadata.coverURL)?.host })

    public init(downloadDuration: TimeInterval = 8, outside: HTTPClient = URLSessionHTTPClient()) {
        self.downloadDuration = downloadDuration
        self.outside = outside
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        if let host = request.url?.host, Self.outsideHosts.contains(host) {
            return try await outside.send(request)
        }
        return answer(request)
    }

    /// What the demo's invented store and library say to a request.
    private func answer(_ request: URLRequest) -> HTTPResponse {
        let path = request.url?.path ?? ""
        switch (request.url?.host ?? "", path) {
        case (DemoFiles.coversHost, _):
            let sku = request.url?.deletingPathExtension().lastPathComponent ?? ""
            return HTTPResponse(data: DemoFiles.cover(sku: sku) ?? Data(),
                                statusCode: DemoFiles.cover(sku: sku) == nil ? 404 : 200, finalURL: request.url)
        case (_, "/login.php"):
            return reply("", finalPath: request.httpMethod == "POST" ? "/account.php" : path, to: request)
        case (_, "/customer/current.jwt"):
            return reply(Self.makeToken(), to: request)
        case (_, "/customer-library"):
            return reply(Self.libraryPage(number: Self.queryValue("page", in: request) ?? "1"), to: request)
        case (_, "/api/library/download"):
            // The ticket is the file's name, the `key` Scrollkeeper asks for.
            return reply(Self.json(["data": Self.requestedKey(in: request)]), to: request)
        case (_, let ticket) where ticket.hasPrefix("/api/library/download/"):
            return reply(Self.json(["data": DemoFiles.address(of: request.url?.lastPathComponent ?? "")]),
                         to: request)
        case (_, let lookup) where lookup.hasPrefix("/api/library/entitlement/customer/"):
            return reply(Self.record(packageID: request.url?.lastPathComponent ?? ""), to: request)
        case (_, "/graphql"):
            return reply(Self.products(for: request), to: request)
        case (_, "/"):
            return reply(#"{"graphql_token":"demo-storefront-token"}"#, to: request)
        default:
            return HTTPResponse(data: Data(), statusCode: path == "/library/" ? 200 : 404, finalURL: request.url)
        }
    }

    public func download(_ request: URLRequest, to destination: URL, progress: @escaping ProgressHandler) async throws {
        guard request.url?.host == DemoFiles.filesHost else {
            return try await outside.download(request, to: destination, progress: progress)
        }
        let steps = 40
        for step in 1...steps {
            try await Task.sleep(for: .seconds(downloadDuration / Double(steps)))
            progress(Double(step) / Double(steps))
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        if let file = request.url.flatMap({ DemoFiles.bundled($0.lastPathComponent) }) {
            try FileManager.default.copyItem(at: file, to: destination)
        } else {
            try DemoFiles.placeholderPDF.write(to: destination)
        }
    }

    /// The `key` field of a download ticket request: the file's name.
    private static func requestedKey(in request: URLRequest) -> String {
        let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
        return body?["key"] as? String ?? ""
    }

    private func reply(_ text: String, finalPath: String = "", to request: URLRequest) -> HTTPResponse {
        var url = request.url
        if !finalPath.isEmpty, let original = request.url {
            var components = URLComponents(url: original, resolvingAgainstBaseURL: false)
            components?.path = finalPath
            url = components?.url
        }
        return HTTPResponse(data: Data(text.utf8), finalURL: url)
    }

    /// A token in the shape of Paizo's, valid for fifteen minutes from now.
    private static func makeToken() -> String {
        let claims = #"{"exp":\#(Int(Date().timeIntervalSince1970) + 900)}"#
        let payload = Data(claims.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "demo.\(payload).token"
    }

    /// The library page as the real site delivers it: data inside a script chunk.
    private static func libraryPage(number: String) -> String {
        let records = number == "1" ? DemoCatalog.records : []
        let properties: [String: Any] = ["entitlements": records, "count": DemoCatalog.records.count]
        let row = "4:" + json(["$", "$Lb", NSNull(), properties]) + "\n"
        return "<html><body><script>self.__next_f.push([1,\(json(row))])</script></body></html>"
    }

    /// One entitlement, as the lookup that checks for updated files receives it.
    private static func record(packageID: String) -> String {
        let record = DemoCatalog.records.first { $0["DigitalPackageID"] as? String == packageID }
        return json(["data": record ?? [:]])
    }

    private static func products(for request: URLRequest) -> String {
        let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
        let variables = body?["variables"] as? [String: String] ?? [:]
        var site: [String: Any] = [:]
        for (name, sku) in variables {
            site["p" + name.dropFirst()] = DemoCatalog.product(sku: sku) ?? NSNull()
        }
        return json(["data": ["site": site]])
    }

    private static func json(_ value: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    private static func queryValue(_ name: String, in request: URLRequest) -> String? {
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        return components?.queryItems?.first(where: { $0.name == name })?.value
    }
}
