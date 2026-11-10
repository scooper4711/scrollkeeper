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
            if !environment.settings.hasCompletedFullSync {
                startFullSync()
            }
        } catch {
            account = .failed(message: error.localizedDescription)
        }
    }

    /// Forgets the account and its library: the stored credentials, the catalog, the covers and the update
    /// checks, so that nothing of the account stays on the device and the next sign-in starts a full sync.
    /// The user's tags and downloaded files are kept, so removing the account and signing in again (after a
    /// password change, say) loses nothing the user made.
    public func signOut() async {
        do {
            try environment.credentials.delete()
        } catch {
            account = .failed(message: error.localizedDescription)
            return
        }
        account = .signedOut
        await stopAccountWork()
        forgetLibrary()
    }

    public var storedEmail: String {
        environment.credentials.load()?.email ?? ""
    }

    /// Stops everything that talks to Paizo and waits for it, so that no late page or cover lands afterwards.
    private func stopAccountWork() async {
        cancelSync()
        metadataTask?.cancel()
        updateCheckTask?.cancel()
        cancelAllDownloads()
        await waitUntilIdle()
    }

    private func forgetLibrary() {
        snapshot = CatalogSnapshot(tags: snapshot.tags)
        updateCheckLog = UpdateCheckLog()
        lastUpdateCheck = nil
        pendingSKUs = []
        requestedSKUs = []
        sync = SyncProgress()
        artwork = ArtworkProgress()
        environment.settings.hasCompletedFullSync = false
        covers.removeAll()
        persist { try await $0.removeAccountData() }
        rebuildItems()
    }
}
