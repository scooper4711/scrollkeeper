import Foundation
import TablesideShared

/// The outside world the store depends on. Tests supply stubs and temporary directories.
public struct LibraryEnvironment: Sendable {
    public var http: HTTPClient
    public var credentials: CredentialStore
    /// Holds the catalog, metadata and tags.
    public var dataDirectory: URL
    /// Where downloaded files go unless the user chooses another folder.
    public var defaultDownloadDirectory: URL
    /// Cover artwork, one image per SKU.
    public var coversDirectory: URL
    /// Scrollkeeper's folder in the Tableside Toolkit's App Group (`ToolkitGroup.scrollkeeperFolder()`), where the
    /// other toolkit apps find its downloads, covers and library list; nil outside the group, and in demo mode.
    public var toolkitFolder: URL?
    public var settings: SettingsStore
    /// How much the app asks Paizo about updated files.
    public var updateCheckPolicy = UpdateCheckPolicy.standard
    /// The current time. Tests supply their own.
    public var now: @Sendable () -> Date = { Date() }
    /// The free titles added to every library; the app adds `BuiltInTitles.all`.
    public var builtInTitles: [BuiltInTitle] = []
    /// True for the demo library (`demo()`), whose data is thrown away when it ends.
    public var isDemo = false

    public init(
        http: HTTPClient,
        credentials: CredentialStore,
        dataDirectory: URL,
        settings: SettingsStore
    ) {
        self.http = http
        self.credentials = credentials
        self.dataDirectory = dataDirectory
        defaultDownloadDirectory = dataDirectory.appending(path: "Files", directoryHint: .isDirectory)
        coversDirectory = dataDirectory.appending(path: "Covers", directoryHint: .isDirectory)
        self.settings = settings
    }

    /// The real thing: URLSession, the Keychain and the app's own folders.
    ///
    /// On a Mac downloads and covers go into the toolkit folder the Tableside Toolkit apps share, unless the user
    /// chooses another place for downloads; a build outside the App Group keeps them in the data folder. On an
    /// iPad downloads go into the app's Documents folder, which the Files app shows.
    public static func live() -> LibraryEnvironment {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        var environment = LibraryEnvironment(
            http: URLSessionHTTPClient(),
            credentials: KeychainCredentialStore(),
            dataDirectory: support.appending(path: "Scrollkeeper", directoryHint: .isDirectory),
            settings: SettingsStore(suiteName: "")
        )
        environment.builtInTitles = BuiltInTitles.all
        #if os(macOS)
        if let toolkit = ToolkitGroup.scrollkeeperFolder() {
            DemoSharing.removeDemo(from: toolkit)
            environment.useToolkitFolder(toolkit)
        }
        #endif
        #if os(iOS)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            environment.defaultDownloadDirectory = documents
        }
        #endif
        return environment
    }

    /// Keeps the downloads and covers in `folder` from now on, moving those in the data folder there the first
    /// time.
    /// Shares the demo's downloads, covers and library list through `folder` when no real library is there
    /// (library-manager 13.7).
    mutating func useDemoToolkitFolder(_ folder: URL) {
        guard DemoSharing.canShare(in: folder), (try? DemoSharing.claim(folder)) != nil else { return }
        toolkitFolder = folder
        defaultDownloadDirectory = folder.appending(path: "Files", directoryHint: .isDirectory)
        coversDirectory = folder.appending(path: "Covers", directoryHint: .isDirectory)
    }

    mutating func useToolkitFolder(_ folder: URL) {
        let move = FolderMove()
        toolkitFolder = folder
        defaultDownloadDirectory = move.destination(
            legacy: defaultDownloadDirectory, shared: folder.appending(path: "Files", directoryHint: .isDirectory)
        )
        coversDirectory = move.destination(
            legacy: coversDirectory, shared: folder.appending(path: "Covers", directoryHint: .isDirectory)
        )
    }
}

extension LibraryEnvironment {
    /// The launch argument that starts the app in demo mode.
    public static let demoArgument = "-ScrollkeeperDemo"

    /// The environment the app should run in: demo mode when launched with `demoArgument`.
    public static func forLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> LibraryEnvironment {
        arguments.contains(demoArgument) ? demo() : live()
    }

    /// An invented library served from inside the app, already signed in, kept in a temporary folder that starts
    /// empty on every launch. Only the free titles' downloads reach the network, and nothing the Keychain. On the Mac
    /// it shares through the App Group when no real library is there (library-manager 13.7).
    public static func demo(downloadDuration: TimeInterval = 8,
                            outside: HTTPClient = URLSessionHTTPClient()) -> LibraryEnvironment {
        let run = UUID().uuidString
        var environment = LibraryEnvironment(
            http: DemoHTTPClient(downloadDuration: downloadDuration, outside: outside),
            credentials: InMemoryCredentialStore(Credentials(email: "demo@example.com", password: "demo")),
            dataDirectory: FileManager.default.temporaryDirectory.appending(path: "ScrollkeeperDemo-" + run),
            settings: SettingsStore(suiteName: "ScrollkeeperDemo-" + run)
        )
        environment.isDemo = true
        // The free titles every library has, downloaded from Paizo as in a real one (13.6).
        environment.builtInTitles = BuiltInTitles.all
        #if os(macOS)
        if let toolkit = ToolkitGroup.scrollkeeperFolder() {
            environment.useDemoToolkitFolder(toolkit)
        }
        #endif
        return environment
    }
}

/// User settings kept in user defaults.
public struct SettingsStore: Sendable {
    private let suiteName: String

    /// An empty suite name means the app's standard defaults.
    public init(suiteName: String) {
        self.suiteName = suiteName
    }

    /// The folder the user chose for downloads, or an empty string for the default.
    public var downloadDirectoryPath: String {
        get { defaults.string(forKey: Self.downloadDirectoryKey) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Self.downloadDirectoryKey) }
    }

    /// A bookmark of the folder the user chose for downloads, which reaches it from inside the App Sandbox.
    /// Nil for the default folder, and for a folder chosen before bookmarks were kept.
    public var downloadDirectoryBookmark: Data? {
        get { defaults.data(forKey: Self.downloadDirectoryBookmarkKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.downloadDirectoryBookmarkKey) }
    }

    /// False until a full sync has run to the end, so an interrupted first sync is started again.
    public var hasCompletedFullSync: Bool {
        get { defaults.bool(forKey: Self.completedFullSyncKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.completedFullSyncKey) }
    }

    /// The `ProductMetadata.schemaVersion` the stored metadata was fetched with.
    public var metadataVersion: Int {
        get { defaults.integer(forKey: Self.metadataVersionKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.metadataVersionKey) }
    }

    /// Whether the app looks for a newer version when it opens. On until the user turns it off.
    public var checksForUpdatesAtLaunch: Bool {
        get { defaults.object(forKey: Self.updateCheckAtLaunchKey) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Self.updateCheckAtLaunchKey) }
    }

    private var defaults: UserDefaults {
        (suiteName.isEmpty ? nil : UserDefaults(suiteName: suiteName)) ?? .standard
    }

    /// The key of `checksForUpdatesAtLaunch`, for views that bind a switch to it.
    public static let updateCheckAtLaunchKey = "checksForUpdatesAtLaunch"
    private static let downloadDirectoryKey = "downloadDirectoryPath"
    private static let downloadDirectoryBookmarkKey = "downloadDirectoryBookmark"
    private static let completedFullSyncKey = "hasCompletedFullSync"
    private static let metadataVersionKey = "metadataVersion"
}
