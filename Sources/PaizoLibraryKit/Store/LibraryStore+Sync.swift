import Foundation

extension LibraryStore {
    /// Fetches every entitlement. Entitlements Paizo no longer lists are dropped when it completes.
    public func startFullSync() {
        runSync { store in
            let seen = SeenIdentifiers()
            try await CatalogSynchronizer(client: store.catalog).fetchAll { page in
                await seen.insert(page.entitlements.map(\.packageID))
                await store.merge(page)
            }
            await store.completeFullSync(seen: seen.all)
        }
    }

    /// Fetches only entitlements newer than the ones already known.
    public func startRefresh() {
        let known = Set(snapshot.entitlements.map(\.packageID))
        runSync { store in
            try await CatalogSynchronizer(client: store.catalog).fetchNew(knownIDs: known) { page in
                await store.merge(page)
            }
        }
    }

    /// Stops the running sync. What was fetched so far is kept.
    public func cancelSync() {
        syncTask?.cancel()
    }

    /// Waits for the running sync and artwork fetch, if any. Used by tests.
    public func waitUntilIdle() async {
        await syncTask?.value
        await metadataTask?.value
        await persistTask?.value
    }

    private func runSync(_ work: @escaping @Sendable (LibraryStore) async throws -> Void) {
        guard !sync.isRunning else { return }
        sync = SyncProgress(isRunning: true, fetched: 0, total: sync.total)
        syncTask = Task { [weak self] in
            guard let self else { return }
            var failure = ""
            do {
                try await work(self)
            } catch is CancellationError {
                failure = ""
            } catch {
                failure = error.localizedDescription
            }
            finishSync(failure: failure)
        }
    }

    private func finishSync(failure: String) {
        sync.isRunning = false
        sync.failure = failure
        let entitlements = snapshot.entitlements
        persist { try await $0.save(entitlements: entitlements) }
    }

    /// Adds a fetched page: known entitlements are updated in place, new ones are added.
    private func merge(_ page: SyncPage) {
        var positions: [String: Int] = [:]
        for (index, entitlement) in snapshot.entitlements.enumerated() {
            positions[entitlement.packageID] = index
        }
        var added: [Entitlement] = []
        for entitlement in page.entitlements {
            if let index = positions[entitlement.packageID] {
                snapshot.entitlements[index] = entitlement
            } else {
                added.append(entitlement)
            }
        }
        snapshot.entitlements.append(contentsOf: added)
        sync.fetched = page.fetchedCount
        sync.total = page.totalCount
        rebuildItems()
        enqueueMissingMetadata()
    }

    /// Called when every page has been fetched: drops what Paizo no longer lists.
    private func completeFullSync(seen: Set<String>) {
        environment.settings.hasCompletedFullSync = true
        snapshot.entitlements.removeAll { !seen.contains($0.packageID) }
        rebuildItems()
    }

    /// Queues storefront lookups for titles that have no metadata or whose cover is missing.
    func enqueueMissingMetadata() {
        let missing = Set(items.map(\.sku)).filter { sku in
            !sku.isEmpty && !requestedSKUs.contains(sku) && needsMetadata(sku)
        }
        guard !missing.isEmpty else { return }
        requestedSKUs.formUnion(missing)
        pendingSKUs.append(contentsOf: missing.sorted())
        artwork.total += missing.count
        if metadataTask == nil {
            metadataTask = Task { [weak self] in await self?.drainMetadataQueue() }
        }
    }

    private func needsMetadata(_ sku: String) -> Bool {
        guard let known = snapshot.metadata[sku] else { return true }
        return !known.coverURL.isEmpty && !covers.hasCover(sku: sku)
    }

    private func drainMetadataQueue() async {
        var batchesSinceSave = 0
        while !pendingSKUs.isEmpty, !Task.isCancelled {
            let batch = Array(pendingSKUs.prefix(StorefrontClient.batchSize))
            pendingSKUs.removeFirst(batch.count)
            for metadata in await metadataSynchronizer.fetch(metadataRequests(for: batch)) {
                snapshot.metadata[metadata.sku] = metadata
            }
            artwork.done += batch.count
            rebuildItems()
            batchesSinceSave += 1
            if batchesSinceSave >= Self.metadataBatchesPerSave {
                batchesSinceSave = 0
                saveMetadata()
            }
        }
        saveMetadata()
        artwork = ArtworkProgress()
        metadataTask = nil
    }

    private func metadataRequests(for skus: [String]) -> [MetadataRequest] {
        let fallbacks = Dictionary(items.map { ($0.sku, $0.fallbackImageURL) }, uniquingKeysWith: { first, _ in first })
        return skus.map { MetadataRequest(sku: $0, fallbackImageURL: fallbacks[$0] ?? "") }
    }

    private func saveMetadata() {
        let metadata = snapshot.metadata
        persist { try await $0.save(metadata: metadata) }
    }

    private static let metadataBatchesPerSave = 20
}

/// Collects the identifiers seen during a full sync, across concurrently fetched pages.
private actor SeenIdentifiers {
    private(set) var all: Set<String> = []

    func insert(_ identifiers: [String]) {
        all.formUnion(identifiers)
    }
}
