import Foundation

/// Stands in for Paizo's store and library in demo mode: an invented library, instant sign-in
/// and unhurried downloads, without touching the network. The app's UI tests run against it,
/// and it lets the app be shown without a real account.
public struct DemoHTTPClient: HTTPClient {
    /// How long each download takes, so that progress, waiting and canceling can be seen.
    private let downloadDuration: TimeInterval

    public init(downloadDuration: TimeInterval = 8) {
        self.downloadDuration = downloadDuration
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        let path = request.url?.path ?? ""
        switch (request.url?.host ?? "", path) {
        case (_, "/login.php"):
            return reply("", finalPath: request.httpMethod == "POST" ? "/account.php" : path, to: request)
        case (_, "/customer/current.jwt"):
            return reply(Self.makeToken(), to: request)
        case (_, "/customer-library"):
            return reply(Self.libraryPage(number: Self.queryValue("page", in: request) ?? "1"), to: request)
        case (_, "/api/library/download"):
            return reply(#"{"data":"demo-ticket"}"#, to: request)
        case (_, "/api/library/download/demo-ticket"):
            return reply(#"{"data":"https://files.demo.invalid/download"}"#, to: request)
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
        let steps = 40
        for step in 1...steps {
            try await Task.sleep(for: .seconds(downloadDuration / Double(steps)))
            progress(Double(step) / Double(steps))
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(Self.samplePDF.utf8).write(to: destination)
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

    /// A one-page PDF, so that a demo download can be opened.
    private static let samplePDF = """
    %PDF-1.4
    1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
    2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
    3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Contents 4 0 R
    /Resources << /Font << /F1 5 0 R >> >> >> endobj
    4 0 obj << /Length 58 >> stream
    BT /F1 18 Tf 40 100 Td (Scrollkeeper demo file) Tj ET
    endstream endobj
    5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj
    trailer << /Root 1 0 R >>
    %%EOF
    """
}
