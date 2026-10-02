import Foundation
@testable import ScrollkeeperKit

/// Registers handlers on a `StubHTTPClient` that behave like Paizo's store and library app.
struct FakePaizo {
    static let token = "header.payload.signature"
    static let account = Credentials(email: "gamer@example.com", password: "p&ss word=1")

    let http = StubHTTPClient()

    /// A token in JSON Web Token form that expires at the given time.
    static func makeToken(expiresAt expiry: Date, label: String = "t") -> String {
        // Written by hand so that the same claims always give the same token.
        let claims = #"{"exp":\#(Int(expiry.timeIntervalSince1970)),"label":"\#(label)"}"#
        let payload = Data(claims.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "header.\(payload).signature"
    }

    /// A signed-in store session: token requests succeed straight away.
    func installSignedInStore() {
        installSignIn()
        http.on("GET https://store.paizo.com/customer/current.jwt", text: Self.token)
    }

    /// Sign-in that accepts `FakePaizo.account` and rejects everything else.
    func installSignIn() {
        http.on("GET https://store.paizo.com/login.php", text: "<form></form>")
        http.on("POST https://store.paizo.com/login.php?action=check_login") { request in
            let body = String(bytes: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            let accepted = body == "login_email=gamer%40example.com&login_pass=p%26ss%20word%3D1"
            let landing = accepted ? "/account.php?action=order_status" : "/login.php"
            return HTTPResponse(data: Data(), finalURL: URL(string: "https://store.paizo.com" + landing))
        }
        http.on("https://store.paizo.com/library/", text: "<script>const appUrl = \"https://app.paizo.com\";</script>")
    }

    /// Library pages of `pageSize` records each.
    func installLibrary(records: [[String: Any]], pageSize: Int = 2) {
        let pages = stride(from: 0, to: records.count, by: pageSize).map {
            Array(records[$0..<min($0 + pageSize, records.count)])
        }
        let total = records.count
        let html = pages.map { Fixtures.libraryPageHTML(records: $0, count: total) }
        http.on("https://app.paizo.com/customer-library") { request in
            let number = Self.queryValue("page", in: request).flatMap { Int($0) } ?? 1
            let body = html.indices.contains(number - 1)
                ? html[number - 1]
                : Fixtures.libraryPageHTML(records: [], count: total)
            return HTTPResponse(data: Data(body.utf8), finalURL: request.url)
        }
    }

    /// The two-step download API ending in a signed URL that serves `contents`.
    func installDownloads(contents: String = "%PDF-fake") {
        http.on("POST https://app.paizo.com/api/library/download", json: ["data": "ticket-1"])
        http.on("GET https://app.paizo.com/api/library/download/ticket-1", json: ["data": "https://s3.example/signed"])
        http.on("https://s3.example/signed", text: contents)
    }

    /// The storefront home page and product query. `products` maps SKU to a product node.
    func installStorefront(products: [String: [String: Any]]) {
        http.on("GET https://store.paizo.com/", text: #"{"graphql_token":"anonymous-token"}"#)
        let nodes = products.mapValues(Fixtures.jsonString)
        http.on("POST https://store.paizo.com/graphql") { request in
            let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
            let variables = body?["variables"] as? [String: String] ?? [:]
            let entries = variables.map { name, sku in "\"p\(name.dropFirst())\": \(nodes[sku] ?? "null")" }
            let answer = "{\"data\": {\"site\": {\(entries.joined(separator: ", "))}}}"
            return HTTPResponse(data: Data(answer.utf8), finalURL: request.url)
        }
        http.on("https://cdn.example/", text: "jpeg-bytes")
    }

    static func productNode(sku: String, name: String, brand: String = "Pathfinder 2E") -> [String: Any] {
        [
            "sku": sku,
            "name": name,
            "path": "/\(sku.lowercased())/",
            "plainTextDescription": " An adventure for 3rd- through 5th-level characters. ",
            "brand": ["name": brand],
            "defaultImage": ["url": "https://cdn.example/\(sku).jpg"],
            "categories": ["edges": [["node": ["breadcrumbs": ["edges": [
                ["node": ["name": "Pathfinder"]], ["node": ["name": "Adventures"]]
            ]]]]]],
            "customFields": ["edges": [["node": ["name": "Page Count", "value": "64"]]]]
        ]
    }

    static func queryValue(_ name: String, in request: URLRequest) -> String? {
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        return components?.queryItems?.first(where: { $0.name == name })?.value
    }
}
