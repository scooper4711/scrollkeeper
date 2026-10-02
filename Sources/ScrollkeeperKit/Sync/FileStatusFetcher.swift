import Foundation

/// Asks Paizo about the files of editions, a few at a time.
struct FileStatusFetcher: Sendable {
    let client: LibraryCatalogClient
    let concurrentLookups: Int

    /// Stops at the first failure and returns what it has learned by then.
    func fetch(_ packageIDs: [String]) async -> [FileStatus] {
        var learned: [FileStatus] = []
        var waiting = packageIDs[...]
        await withTaskGroup(of: FileStatus?.self) { group in
            for packageID in waiting.prefix(concurrentLookups) {
                group.addTask { try? await client.fetchFileStatus(packageID: packageID) }
            }
            waiting = waiting.dropFirst(concurrentLookups)
            while let answer = await group.next() {
                guard let status = answer else {
                    group.cancelAll()
                    break
                }
                learned.append(status)
                if let packageID = waiting.popFirst() {
                    group.addTask { try? await client.fetchFileStatus(packageID: packageID) }
                }
            }
        }
        return learned
    }
}
