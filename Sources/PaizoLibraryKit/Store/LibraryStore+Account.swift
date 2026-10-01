import Foundation

extension LibraryStore {
    /// Verifies the account with Paizo and, when accepted, stores it and starts the first sync.
    public func signIn(email: String, password: String) async {
        let credentials = Credentials(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        guard credentials.isComplete else {
            account = .failed(message: "Enter both the email address and the password of your Paizo account.")
            return
        }
        account = .verifying
        do {
            try await session.signIn(with: credentials)
            try environment.credentials.save(credentials)
            account = .signedIn(email: credentials.email)
            if snapshot.entitlements.isEmpty {
                startFullSync()
            }
        } catch {
            account = .failed(message: error.localizedDescription)
        }
    }

    /// Forgets the stored account. The catalog and downloaded files are kept.
    public func signOut() {
        cancelSync()
        do {
            try environment.credentials.delete()
            account = .signedOut
        } catch {
            account = .failed(message: error.localizedDescription)
        }
    }

    public var storedEmail: String {
        environment.credentials.load()?.email ?? ""
    }
}
