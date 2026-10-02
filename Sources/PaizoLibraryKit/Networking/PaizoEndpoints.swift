import Foundation

/// Where Paizo's store and library app live.
public struct PaizoEndpoints: Sendable, Equatable {
    public var store: URL
    public var app: URL
    /// Identifies the library app when asking the store for a customer token.
    public var appID: String

    public init(store: URL, app: URL, appID: String) {
        self.store = store
        self.app = app
        self.appID = appID
    }

    public static let standard = PaizoEndpoints(
        store: webURL("https://store.paizo.com"),
        app: webURL("https://app.paizo.com"),
        appID: "rpb6179oxtn7up8olq2q0d8kt0iamgc"
    )

    /// The store's library page publishes the app address and id; use them when present.
    public func applying(libraryPageHTML html: String) -> PaizoEndpoints {
        var updated = self
        if let address = Self.appURLPattern.captures(in: html).last, let url = URL(string: address) {
            updated.app = url
        }
        if let identifier = Self.appIDPattern.captures(in: html).last {
            updated.appID = identifier
        }
        return updated
    }

    func storeURL(_ path: String, query: [URLQueryItem] = []) -> URL {
        Self.url(base: store, path: path, query: query)
    }

    func appURL(_ path: String, query: [URLQueryItem] = []) -> URL {
        Self.url(base: app, path: path, query: query)
    }

    private static func url(base: URL, path: String, query: [URLQueryItem]) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        return components.url ?? base
    }

    /// Builds a URL from a constant address without force-unwrapping.
    private static func webURL(_ address: String) -> URL {
        URL(string: address) ?? URL(filePath: "/")
    }

    private static let appURLPattern = TextPattern(#"const\s+appUrl\s*=\s*"(https://[^"]+)""#)
    private static let appIDPattern = TextPattern(#"const\s+appId\s*=\s*"([A-Za-z0-9]+)""#)
}
