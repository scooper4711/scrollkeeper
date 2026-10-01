import Foundation
import Observation

public struct SyncProgress: Equatable, Sendable {
    public var isRunning = false
    public var fetched = 0
    public var total = 0
    /// Why the last sync stopped early; empty when it did not.
    public var failure = ""

    public var fraction: Double { total > 0 ? min(1, Double(fetched) / Double(total)) : 0 }
}

public struct ArtworkProgress: Equatable, Sendable {
    public var done = 0
    public var total = 0

    public var isRunning: Bool { done < total }
    public var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
}

public enum AccountState: Equatable, Sendable {
    case signedOut
    case verifying
    case signedIn(email: String)
    case failed(message: String)
}

public enum DownloadState: Equatable, Sendable {
    case inProgress(Double)
    case failed(String)
}

/// The app's state: the catalog, what is visible, and everything in progress.
///
/// Views read these properties and call the methods; all logic stays here and in the types it uses.
@MainActor
@Observable
public final class LibraryStore {
    public internal(set) var items: [LibraryItem] = []
    public internal(set) var visibleItems: [LibraryItem] = []
    public internal(set) var facets = LibraryFacets()
    public internal(set) var sync = SyncProgress()
    public internal(set) var artwork = ArtworkProgress()
    public internal(set) var account = AccountState.signedOut
    public internal(set) var downloads: [String: DownloadState] = [:]
    public internal(set) var downloadedItemIDs: Set<String> = []
    public internal(set) var locator: FileLocator

    public var query = LibraryQuery() {
        didSet { refreshVisibleItems() }
    }

    public var sortOrder = [KeyPathComparator(\LibraryItem.titleSortKey)] {
        didSet { refreshVisibleItems() }
    }

    let environment: LibraryEnvironment
    let session: PaizoSession
    let catalog: LibraryCatalogClient
    let repository: LibraryRepository
    let covers: CoverStore
    let metadataSynchronizer: MetadataSynchronizer
    let tagger = FinderTagger()
    let grouper = EntitlementGrouper()

    var snapshot = CatalogSnapshot()
    var syncTask: Task<Void, Never>?
    var metadataTask: Task<Void, Never>?
    var pendingSKUs: [String] = []
    var requestedSKUs: Set<String> = []
    var downloadTasks: [String: Task<Void, Never>] = [:]
    var persistTask: Task<Void, Never>?

    public init(environment: LibraryEnvironment) {
        self.environment = environment
        session = PaizoSession(http: environment.http, credentials: environment.credentials)
        catalog = LibraryCatalogClient(http: environment.http, session: session)
        repository = LibraryRepository(directory: environment.dataDirectory)
        covers = CoverStore(directory: environment.dataDirectory.appending(path: "Covers", directoryHint: .isDirectory))
        metadataSynchronizer = MetadataSynchronizer(
            storefront: StorefrontClient(http: environment.http), http: environment.http, covers: covers
        )
        locator = FileLocator(root: Self.downloadDirectory(in: environment))
    }

    /// Loads the stored catalog and, when an account exists but no catalog does, starts a full sync.
    public func start() async {
        snapshot = await repository.load()
        rebuildItems()
        importFinderTags()
        if let stored = environment.credentials.load(), stored.isComplete {
            account = .signedIn(email: stored.email)
        }
        enqueueMissingMetadata()
        if account != .signedOut, snapshot.entitlements.isEmpty {
            startFullSync()
        }
    }

    public func item(id: LibraryItem.ID?) -> LibraryItem? {
        id.flatMap { wanted in items.first(where: { $0.id == wanted }) }
    }

    /// The cached cover of a title, or nil when none has been downloaded.
    public func coverURL(for item: LibraryItem) -> URL? {
        covers.hasCover(sku: item.sku) ? covers.url(sku: item.sku) : nil
    }

    public var downloadDirectory: URL { locator.root }

    /// Moves future downloads to another folder. Files already downloaded stay where they are.
    public func setDownloadDirectory(_ url: URL) {
        environment.settings.downloadDirectoryPath = url.path
        locator = FileLocator(root: url)
        refreshDownloadedItems()
    }

    public func resetDownloadDirectory() {
        environment.settings.downloadDirectoryPath = ""
        locator = FileLocator(root: environment.defaultDownloadDirectory)
        refreshDownloadedItems()
    }

    /// Rebuilds titles from the snapshot after entitlements, metadata or tags changed.
    func rebuildItems() {
        items = grouper.makeItems(from: snapshot, reusing: items)
        refreshDownloadedItems()
    }

    func refreshDownloadedItems() {
        downloadedItemIDs = locator.downloadedItemIDs(among: items)
        refreshVisibleItems()
    }

    func refreshVisibleItems() {
        facets = LibraryFacets(items: items, downloadedIDs: downloadedItemIDs)
        visibleItems = query.filter(items, downloadedIDs: downloadedItemIDs).sorted(using: sortOrder)
    }

    /// Queues a repository write off the main actor. Writes run in order, and each one stores the
    /// complete data, so a write that fails is made good by the next.
    func persist(_ write: @escaping @Sendable (LibraryRepository) async throws -> Void) {
        let repository = repository
        let previous = persistTask
        persistTask = Task.detached {
            await previous?.value
            try? await write(repository)
        }
    }

    private static func downloadDirectory(in environment: LibraryEnvironment) -> URL {
        let chosen = environment.settings.downloadDirectoryPath
        return chosen.isEmpty
            ? environment.defaultDownloadDirectory
            : URL(filePath: chosen, directoryHint: .isDirectory)
    }
}
