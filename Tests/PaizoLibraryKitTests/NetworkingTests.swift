import Foundation
@testable import PaizoLibraryKit
import Testing

@Suite struct PaizoSessionTests {
    private let paizo = FakePaizo()

    /// A session whose clock is `clock`; sleeping moves that clock forward instead of waiting.
    private func makeSession(stored: Credentials? = FakePaizo.account, clock: Clock = Clock()) -> PaizoSession {
        let timing = SessionTiming(now: { clock.now }, sleep: { clock.advance(by: $0) })
        return PaizoSession(http: paizo.http, credentials: MemoryCredentialStore(stored), timing: timing)
    }

    @Test func signInPostsFormEncodedCredentials() async throws {
        paizo.installSignIn()
        try await makeSession().signIn(with: FakePaizo.account)
        #expect(paizo.http.count(of: "action=check_login") == 1)
    }

    @Test func signInRejectsWrongPassword() async {
        paizo.installSignIn()
        await #expect(throws: PaizoError.signInRejected) {
            try await makeSession().signIn(with: Credentials(email: "gamer@example.com", password: "wrong"))
        }
    }

    @Test func signInAdoptsEndpointsPublishedByTheLibraryPage() async throws {
        paizo.installSignIn()
        paizo.http.on(
            "https://store.paizo.com/library/",
            text: #"const appUrl = "https://library.example"; const appId = "abc123";"#
        )
        let session = makeSession()
        try await session.signIn(with: FakePaizo.account)

        let endpoints = await session.currentEndpoints()
        #expect(endpoints.app.absoluteString == "https://library.example")
        #expect(endpoints.appID == "abc123")
    }

    /// A store that, like Paizo's, hands out one token until it has expired and then the next.
    private func installCachingStore(clock: Clock) -> Counter {
        paizo.installSignIn()
        let requests = Counter()
        let start = clock.now
        paizo.http.on("/customer/current.jwt") { request in
            requests.increment()
            let period = Int(clock.now.timeIntervalSince(start) / 900)
            let expiry = start.addingTimeInterval(Double(period + 1) * 900)
            let token = FakePaizo.makeToken(expiresAt: expiry, label: "period \(period)")
            return HTTPResponse(data: Data(token.utf8), finalURL: request.url)
        }
        return requests
    }

    @Test func tokenIsReusedWhileItHasLifeLeft() async throws {
        let clock = Clock()
        let requests = installCachingStore(clock: clock)
        let session = makeSession(clock: clock)

        let first = try await session.customerToken()
        clock.advance(by: 900 - PaizoSession.minimumUsableLife - 1)
        #expect(try await session.customerToken() == first)
        #expect(requests.current == 1)
        #expect(paizo.http.count(of: "action=check_login") == 0)
    }

    @Test func waitsOutATokenThatIsAboutToExpire() async throws {
        let clock = Clock()
        let requests = installCachingStore(clock: clock)
        let session = makeSession(clock: clock)
        let first = try await session.customerToken()

        clock.advance(by: 880)
        let second = try await session.customerToken()

        #expect(second != first)
        #expect(TokenClaims.expiry(of: second) == TokenClaims.expiry(of: first)?.addingTimeInterval(900))
        // One request returned the dying token, the next one, after the wait, its successor.
        #expect(requests.current == 3)
        #expect(clock.now.timeIntervalSince(TokenClaims.expiry(of: first) ?? .distantPast) == 2)
    }

    @Test func aTokenThatArrivesAlmostExpiredIsWaitedOutToo() async throws {
        let clock = Clock()
        _ = installCachingStore(clock: clock)
        clock.advance(by: 890)

        let token = try await makeSession(clock: clock).customerToken()

        #expect((TokenClaims.expiry(of: token) ?? .distantPast).timeIntervalSince(clock.now) > 800)
    }

    @Test func renewalReturnsTheSameTokenWhileTheStoreHasNoNewerOne() async throws {
        let clock = Clock()
        let requests = installCachingStore(clock: clock)
        let session = makeSession(clock: clock)
        let token = try await session.customerToken()

        #expect(try await session.renewedCustomerToken(replacing: token) == token)
        #expect(requests.current == 2)
        #expect(paizo.http.count(of: "action=check_login") == 0)
    }

    @Test func callersHoldingAnOlderTokenGetTheCurrentOneWithoutAsking() async throws {
        let clock = Clock()
        let requests = installCachingStore(clock: clock)
        let session = makeSession(clock: clock)
        let current = try await session.customerToken()

        #expect(try await session.renewedCustomerToken(replacing: "an.older.token") == current)
        #expect(requests.current == 1)
    }

    @Test func tokenWithUnreadableExpiryIsRenewedAfterTheFallbackLifetime() async throws {
        paizo.installSignedInStore()
        let clock = Clock()
        let session = makeSession(clock: clock)
        _ = try await session.customerToken()

        clock.advance(by: PaizoSession.fallbackLifetime - PaizoSession.minimumUsableLife - 1)
        _ = try await session.customerToken()
        #expect(paizo.http.count(of: "current.jwt") == 1)

        clock.advance(by: 2)
        _ = try await session.customerToken()
        #expect(paizo.http.count(of: "current.jwt") == 2)
    }

    @Test func liveTimingUsesTheRealClock() async {
        let before = Date()
        await SessionTiming.live.sleep(0.01)
        #expect(SessionTiming.live.now() >= before.addingTimeInterval(0.01))
    }

    @Test func readsTheExpiryClaimOfAToken() {
        let expiry = Date(timeIntervalSince1970: 1_800_000_900)
        #expect(TokenClaims.expiry(of: FakePaizo.makeToken(expiresAt: expiry)) == expiry)
        #expect(TokenClaims.expiry(of: "header.payload.signature") == nil)
        #expect(TokenClaims.expiry(of: "not a token") == nil)
    }

    @Test func signsInWithStoredCredentialsWhenStoreSessionIsMissing() async throws {
        paizo.installSignIn()
        let signedIn = Flag()
        paizo.http.on("POST https://store.paizo.com/login.php?action=check_login") { _ in
            signedIn.set()
            return HTTPResponse(data: Data(), finalURL: URL(string: "https://store.paizo.com/account.php"))
        }
        paizo.http.on("/customer/current.jwt") { request in
            let body = signedIn.isSet ? FakePaizo.token : "<html>Please sign in</html>"
            return HTTPResponse(data: Data(body.utf8), finalURL: request.url)
        }

        #expect(try await makeSession().customerToken() == FakePaizo.token)
    }

    @Test func tokenNeedsCredentials() async {
        paizo.http.on("/customer/current.jwt", text: "", status: 401)
        await #expect(throws: PaizoError.credentialsMissing) {
            try await makeSession(stored: nil).customerToken()
        }
    }

    @Test func tokenFailsWhenStoreNeverIssuesOne() async {
        paizo.installSignIn()
        paizo.http.on("/customer/current.jwt", text: "not a token")
        await #expect(throws: PaizoError.unexpectedResponse(operation: "Requesting the customer token")) {
            try await makeSession().customerToken()
        }
    }

    @Test func concurrentCallersShareOneRenewal() async throws {
        paizo.installSignedInStore()
        let session = makeSession()
        async let first = session.renewedCustomerToken(replacing: "")
        async let second = session.renewedCustomerToken(replacing: "")
        #expect(try await [first, second] == [FakePaizo.token, FakePaizo.token])
        #expect(paizo.http.count(of: "current.jwt") == 1)
    }
}
