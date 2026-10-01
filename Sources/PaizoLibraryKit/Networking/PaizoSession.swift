import Foundation

/// Signs in to the Paizo store and hands out customer tokens for the library app.
public actor PaizoSession {
    /// Paizo's tokens are valid for fifteen minutes; renew well before that.
    static let tokenLifetime: TimeInterval = 600

    private let http: HTTPClient
    private let credentials: CredentialStore
    private let now: @Sendable () -> Date
    private var endpoints: PaizoEndpoints
    private var cachedToken = ""
    private var tokenIssued = Date.distantPast
    private var pendingRenewal: Task<String, Error>?

    public init(
        http: HTTPClient,
        credentials: CredentialStore,
        endpoints: PaizoEndpoints = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.http = http
        self.credentials = credentials
        self.endpoints = endpoints
        self.now = now
    }

    public func currentEndpoints() -> PaizoEndpoints { endpoints }

    /// Signs in with the given account. Throws `PaizoError.signInRejected` when Paizo refuses it.
    public func signIn(with account: Credentials) async throws {
        let loginPage = endpoints.storeURL("/login.php")
        _ = try await http.send(.get(loginPage))
        let checkLogin = endpoints.storeURL("/login.php", query: [URLQueryItem(name: "action", value: "check_login")])
        let fields = [(name: "login_email", value: account.email), (name: "login_pass", value: account.password)]
        let response = try await http.send(.postForm(checkLogin, fields: fields))
        guard response.finalURL?.path.contains("account.php") == true else {
            throw PaizoError.signInRejected
        }
        cachedToken = ""
        await loadEndpoints()
    }

    /// A token for the library app, reused until it is ten minutes old.
    public func customerToken() async throws -> String {
        let age = now().timeIntervalSince(tokenIssued)
        if !cachedToken.isEmpty, age < Self.tokenLifetime {
            return cachedToken
        }
        return try await renewedCustomerToken()
    }

    /// A fresh token. Concurrent callers share one renewal.
    public func renewedCustomerToken() async throws -> String {
        if let pendingRenewal {
            return try await pendingRenewal.value
        }
        let renewal = Task { try await self.fetchToken() }
        pendingRenewal = renewal
        defer { pendingRenewal = nil }
        cachedToken = try await renewal.value
        tokenIssued = now()
        return cachedToken
    }

    private func fetchToken() async throws -> String {
        if let token = try await requestToken() {
            return token
        }
        guard let account = credentials.load(), account.isComplete else {
            throw PaizoError.credentialsMissing
        }
        try await signIn(with: account)
        guard let token = try await requestToken() else {
            throw PaizoError.unexpectedResponse(operation: "Requesting the customer token")
        }
        return token
    }

    /// The token, or nil when the store session is not signed in.
    private func requestToken() async throws -> String? {
        let query = [URLQueryItem(name: "app_client_id", value: endpoints.appID)]
        let response = try await http.send(.get(endpoints.storeURL("/customer/current.jwt", query: query)))
        let token = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let looksLikeToken = token.split(separator: ".").count == 3 && !token.contains("<")
        return response.isSuccess && looksLikeToken ? token : nil
    }

    private func loadEndpoints() async {
        guard let response = try? await http.send(.get(endpoints.storeURL("/library/"))), response.isSuccess else {
            return
        }
        endpoints = endpoints.applying(libraryPageHTML: response.text)
    }
}
