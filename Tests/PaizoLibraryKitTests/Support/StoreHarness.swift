import Foundation
@testable import PaizoLibraryKit

/// A `LibraryStore` wired to a fake Paizo, a temporary directory and in-memory credentials.
@MainActor
final class StoreHarness {
    let paizo = FakePaizo()
    let directory = TemporaryDirectory()
    let credentials: MemoryCredentialStore
    let settingsSuite = "PaizoLibraryKitTests-" + UUID().uuidString

    static let records: [[String: Any]] = [
        Fixtures.record(id: "ap-single", name: "Pathfinder Adventure PDF - Single File", sku: "PZO1E"),
        Fixtures.record(id: "ap-chapters", name: "Pathfinder Adventure PDF - File per Chapter", sku: "PZO1E",
                        file: "chapters.zip"),
        Fixtures.record(id: "map", name: "Pathfinder Flip-Mat: Carnival PDF", sku: "PZO2E", file: "map.pdf")
    ]

    init(account: Credentials? = FakePaizo.account, records: [[String: Any]] = StoreHarness.records) {
        credentials = MemoryCredentialStore(account)
        paizo.installSignedInStore()
        paizo.installLibrary(records: records)
        paizo.installDownloads()
        paizo.installStorefront(products: [
            "PZO1E": FakePaizo.productNode(sku: "PZO1E", name: "Pathfinder Adventure PDF")
        ])
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: settingsSuite)
    }

    var environment: LibraryEnvironment {
        LibraryEnvironment(
            http: paizo.http,
            credentials: credentials,
            dataDirectory: directory.url.appending(path: "data"),
            settings: SettingsStore(suiteName: settingsSuite)
        )
    }

    func makeStore() -> LibraryStore {
        LibraryStore(environment: environment)
    }

    /// A store that has loaded and finished its first sync.
    func makeSyncedStore() async -> LibraryStore {
        let store = makeStore()
        await store.start()
        await store.waitUntilIdle()
        return store
    }
}
