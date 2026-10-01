import Foundation

/// One fetched page, with running totals for the progress bar.
public struct SyncPage: Sendable, Equatable {
    public var entitlements: [Entitlement]
    public var fetchedCount: Int
    public var totalCount: Int
}

public typealias SyncPageHandler = @Sendable (SyncPage) async -> Void

/// Walks the pages of the library listing.
public struct CatalogSynchronizer: Sendable {
    /// Paizo renders a page in about fifteen seconds however many are requested at once.
    public static let concurrentPages = 6
    static let attemptsPerPage = 2

    private let client: LibraryCatalogClient

    public init(client: LibraryCatalogClient) {
        self.client = client
    }

    /// Fetches every page: the first to learn the total, then the rest several at a time.
    public func fetchAll(onPage: @escaping SyncPageHandler) async throws {
        let first = try await fetchWithRetry(1)
        var fetched = first.entitlements.count
        await onPage(SyncPage(entitlements: first.entitlements, fetchedCount: fetched, totalCount: first.totalCount))
        let lastPage = Self.pageCount(total: first.totalCount, pageSize: first.entitlements.count)
        guard lastPage > 1 else { return }

        try await withThrowingTaskGroup(of: LibraryPage.self) { group in
            var next = 2
            while next <= min(lastPage, Self.concurrentPages + 1) {
                group.addTask { [next] in try await fetchWithRetry(next) }
                next += 1
            }
            while let page = try await group.next() {
                fetched += page.entitlements.count
                await onPage(
                    SyncPage(entitlements: page.entitlements, fetchedCount: fetched, totalCount: first.totalCount)
                )
                if next <= lastPage {
                    group.addTask { [next] in try await fetchWithRetry(next) }
                    next += 1
                }
            }
        }
    }

    /// Fetches pages newest first and stops at the first page that holds nothing unknown.
    public func fetchNew(knownIDs: Set<String>, onPage: @escaping SyncPageHandler) async throws {
        var known = knownIDs
        var number = 1
        var lastPage = 1
        repeat {
            let page = try await fetchWithRetry(number)
            if number == 1 {
                // Only the first page is sure to be full, so it tells the page size.
                lastPage = Self.pageCount(total: page.totalCount, pageSize: page.entitlements.count)
            }
            let fresh = page.entitlements.filter { !known.contains($0.packageID) }
            known.formUnion(fresh.map(\.packageID))
            await onPage(SyncPage(entitlements: fresh, fetchedCount: known.count, totalCount: page.totalCount))
            if fresh.isEmpty {
                return
            }
            number += 1
        } while number <= lastPage
    }

    static func pageCount(total: Int, pageSize: Int) -> Int {
        pageSize > 0 ? (total + pageSize - 1) / pageSize : 1
    }

    private func fetchWithRetry(_ number: Int) async throws -> LibraryPage {
        var lastError: Error = PaizoError.unexpectedResponse(operation: "Loading library page \(number)")
        for _ in 0..<Self.attemptsPerPage {
            try Task.checkCancellation()
            do {
                return try await client.fetchPage(number)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError
    }
}
