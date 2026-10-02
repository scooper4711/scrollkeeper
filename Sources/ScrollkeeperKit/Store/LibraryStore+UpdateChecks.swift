import Foundation

/// Finding out whether Paizo has replaced files that are downloaded here. How much is asked,
/// and how often, is decided by `UpdateCheckPolicy`.
extension LibraryStore {
    /// Checks downloaded editions nobody is waiting for: those most overdue, within the day's
    /// allowance. A library downloaded nearly in full is listed again instead, once a month.
    public func checkForFileUpdates() {
        guard case .signedIn = account, environment.settings.hasCompletedFullSync else { return }
        let downloaded = items.filter { downloadedItemIDs.contains($0.id) }
        let plan = environment.updateCheckPolicy.backgroundPlan(
            for: candidates(in: downloaded), log: updateCheckLog, now: environment.now()
        )
        switch plan {
        case .listing:
            startFullSync(concurrentPages: environment.updateCheckPolicy.listingConcurrentPages)
        case let .lookups(packageIDs):
            runFileChecks(packageIDs)
        }
    }

    /// Checks the downloaded editions of a title the user is looking at, unless they were
    /// checked within the last day.
    public func checkForFileUpdates(of item: LibraryTitle) {
        guard case .signedIn = account else { return }
        runFileChecks(candidates(in: [item]).map(\.packageID))
    }

    /// Notes that the whole library has just been listed, which checks every edition at once.
    func recordListing(seen: Set<String>) {
        updateCheckLog.lastListing = environment.now()
        updateCheckLog.lastChecked = updateCheckLog.lastChecked.filter { seen.contains($0.key) }
        saveUpdateCheckLog()
    }

    /// Checks run one after another, so an edition asked about twice is looked up once.
    private func runFileChecks(_ packageIDs: [String]) {
        guard !packageIDs.isEmpty else { return }
        let previous = updateCheckTask
        let policy = environment.updateCheckPolicy
        let fetcher = FileStatusFetcher(client: catalog, concurrentLookups: policy.concurrentLookups)
        updateCheckTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            let due = policy.checkable(packageIDs, log: updateCheckLog, now: environment.now())
            apply(await fetcher.fetch(due))
        }
    }

    private func apply(_ statuses: [FileStatus]) {
        guard !statuses.isEmpty else { return }
        let found = Dictionary(statuses.map { ($0.packageID, $0) }, uniquingKeysWith: { first, _ in first })
        let now = environment.now()
        for index in snapshot.entitlements.indices {
            guard let status = found[snapshot.entitlements[index].packageID] else { continue }
            snapshot.entitlements[index].apply(status)
            updateCheckLog.lastChecked[status.packageID] = now
        }
        rebuildItems()
        let entitlements = snapshot.entitlements
        persist { try await $0.save(entitlements: entitlements) }
        saveUpdateCheckLog()
    }

    private func saveUpdateCheckLog() {
        lastUpdateCheck = updateCheckLog.latest
        let log = updateCheckLog
        persist { try await $0.save(updateChecks: log) }
    }

    /// The downloaded editions among the editions of `titles`.
    private func candidates(in titles: [LibraryTitle]) -> [CheckCandidate] {
        titles.flatMap { item in
            item.editions
                .filter { locator.isDownloaded(locator.target(for: $0, in: item)) }
                .map { edition in
                    let entitlement = edition.entitlement
                    let dates = [item.metadata.releaseDate, entitlement.dateUpdated, entitlement.dateGranted]
                    return CheckCandidate(
                        packageID: entitlement.packageID,
                        lastActivity: dates.compactMap { $0 }.max() ?? .distantPast
                    )
                }
        }
    }
}
