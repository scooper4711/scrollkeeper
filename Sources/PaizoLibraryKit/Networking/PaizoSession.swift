import Foundation

/// The session's view of time. Tests substitute a clock they control.
public struct SessionTiming: Sendable {
    public var now: @Sendable () -> Date
    public var sleep: @Sendable (TimeInterval) async -> Void

    public init(now: @escaping @Sendable () -> Date, sleep: @escaping @Sendable (TimeInterval) async -> Void) {
        self.now = now
        self.sleep = sleep
    }

    public static let live = SessionTiming(
        now: { Date() },
        sleep: { seconds in try? await Task.sleep(for: .seconds(seconds)) }
    )
}

/// Signs in to the Paizo store and hands out customer tokens for the library app.
///
/// A token is valid for fifteen minutes, and the store keeps handing out the same one, to every
/// session of the customer, until it has expired. A token can therefore arrive with little time
/// left, and signing in again does not produce a newer one.
public actor PaizoSession {
    /// A token with less than this long to live is not used to start a request; a library page
    /// takes about fifteen seconds to answer.
    static let minimumUsableLife: TimeInterval = 45
    /// Assumed life of a token whose expiry cannot be read.
    static let fallbackLifetime: TimeInterval = 600

    private let http: HTTPClient
    private let credentials: CredentialStore
    private let timing: SessionTiming
    private var endpoints: PaizoEndpoints
    private var cachedToken = ""
    private var tokenExpiry = Date.distantPast
    private var pendingRenewal: Task<String, Error>?

    public init(
        http: HTTPClient,
        credentials: CredentialStore,
        endpoints: PaizoEndpoints = .standard,
        timing: SessionTiming = .live
    ) {
        self.http = http
        self.credentials = credentials
        self.endpoints = endpoints
        self.timing = timing
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
        await loadEndpoints()
    }

    /// A token for the library app, reused until shortly before it expires.
    public func customerToken() async throws -> String {
        if !cachedToken.isEmpty, remainingLife(until: tokenExpiry) > Self.minimumUsableLife {
            return cachedToken
        }
        return try await renewedCustomerToken(replacing: cachedToken)
    }

    /// A token to use instead of `stale`, which Paizo rejected or which is about to expire.
    /// Callers that hold the same stale token share one renewal.
    public func renewedCustomerToken(replacing stale: String) async throws -> String {
        if !cachedToken.isEmpty, cachedToken != stale {
            return cachedToken
        }
        if let pendingRenewal {
            return try await pendingRenewal.value
        }
        let renewal = Task { try await self.fetchToken() }
        pendingRenewal = renewal
        defer { pendingRenewal = nil }
        cachedToken = try await renewal.value
        tokenExpiry = TokenClaims.expiry(of: cachedToken)
            ?? timing.now().addingTimeInterval(Self.fallbackLifetime)
        return cachedToken
    }

    /// Asks the store for a token. When the store hands out one that is about to expire, waits
    /// until it has, because only then does the store issue the next one.
    private func fetchToken() async throws -> String {
        let token = try await obtainToken()
        guard let expiry = TokenClaims.expiry(of: token) else { return token }
        let remaining = remainingLife(until: expiry)
        guard remaining <= Self.minimumUsableLife else { return token }
        await timing.sleep(max(0, remaining) + 2)
        return try await obtainToken()
    }

    /// The store's current token, signing in first when the store session is not signed in.
    private func obtainToken() async throws -> String {
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

    private func remainingLife(until expiry: Date) -> TimeInterval {
        expiry.timeIntervalSince(timing.now())
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

/// Reads claims from a JSON Web Token without verifying it; the token is only passed on.
enum TokenClaims {
    static func expiry(of token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let seconds = claims["exp"] as? Double
        else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}
