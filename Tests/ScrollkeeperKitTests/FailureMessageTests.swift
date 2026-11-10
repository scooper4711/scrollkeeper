import Foundation
import Testing
@testable import ScrollkeeperKit

@Suite struct FailureMessageTests {
    @Test func unreadablePagesAndAnswersMeanTheSiteChanged() {
        let errors: [Error] = [
            PayloadError.entitlementsMissing,
            PaizoError.unexpectedResponse(operation: "Loading library page 1"),
            PaizoError.http(operation: "Opening Paizo's sign-in page", status: 404)
        ]
        for error in errors {
            #expect(FailureMessage.isSiteChange(error))
            #expect(FailureMessage.text(for: error) == FailureMessage.siteChanged)
        }
        #expect(FailureMessage.siteChanged.contains("has changed"))
        #expect(FailureMessage.siteChanged.lowercased().contains("update"))
    }

    @Test func offlineAndSlowNetworksEachGetTheirOwnMessage() {
        let offline = FailureMessage.text(for: URLError(.notConnectedToInternet))
        let silent = FailureMessage.text(for: URLError(.timedOut))
        #expect(offline.contains("not connected to the internet"))
        #expect(silent.contains("did not answer"))
        #expect(!FailureMessage.isSiteChange(URLError(.timedOut)))
    }

    @Test func paizoBeingDownIsNotASiteChange() {
        let error = PaizoError.http(operation: "Signing in", status: 503)
        #expect(!FailureMessage.isSiteChange(error))
        #expect(FailureMessage.text(for: error).contains("not working right now"))
    }

    @Test func otherFailuresKeepTheirOwnWords() {
        #expect(FailureMessage.text(for: PaizoError.signInRejected) == PaizoError.signInRejected.errorDescription)
        #expect(FailureMessage.text(for: URLError(.badURL)) == URLError(.badURL).localizedDescription)
    }
}

@MainActor
@Suite struct SignInFailureTests {
    private let harness = StoreHarness(account: nil)

    private func signIn() async -> AccountState {
        let store = harness.makeStore()
        await store.signIn(email: FakePaizo.account.email, password: FakePaizo.account.password)
        return store.account
    }

    private func failureMessage() async -> String {
        guard case let .failed(message) = await signIn() else { return "" }
        return message
    }

    @Test func changedSignInPageSaysThatThePaizoSiteChanged() async {
        harness.paizo.http.on("GET https://store.paizo.com/login.php", text: "gone", status: 404)
        #expect(await signIn() == .failed(message: FailureMessage.siteChanged))
    }

    @Test func paizoBeingDownSaysSo() async {
        harness.paizo.http.on("GET https://store.paizo.com/login.php", text: "", status: 503)
        #expect(await failureMessage().contains("not working right now"))
    }

    @Test func noNetworkSaysSo() async {
        harness.paizo.http.on("GET https://store.paizo.com/login.php") { _ in throw URLError(.notConnectedToInternet) }
        #expect(await failureMessage().contains("not connected to the internet"))
    }

    @Test func wrongPasswordStillSaysPaizoDidNotAcceptIt() async {
        let store = harness.makeStore()
        await store.signIn(email: FakePaizo.account.email, password: "wrong")
        #expect(store.account == .failed(message: PaizoError.signInRejected.errorDescription ?? ""))
    }

    @Test func aLibraryPageThatCannotBeReadEndsTheSyncWithTheSiteChangedMessage() async {
        let signedIn = StoreHarness()
        signedIn.paizo.http.on("GET https://app.paizo.com/customer-library", text: "<html>redesigned</html>")

        let store = await signedIn.makeSyncedStore()

        #expect(!store.sync.isRunning)
        #expect(store.sync.failure == FailureMessage.siteChanged)
    }
}
