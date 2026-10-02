import Foundation

/// The outside world the store depends on. Tests supply stubs and temporary directories.
public struct LibraryEnvironment: Sendable {
    public var http: HTTPClient
    public var credentials: CredentialStore
    /// Holds the catalog, metadata, tags and cover artwork.
    public var dataDirectory: URL
    /// Where downloaded files go unless the user chooses another folder.
    public var defaultDownloadDirectory: URL
    public var settings: SettingsStore
    /// How much the app asks Paizo about updated files.
    public var updateCheckPolicy = UpdateCheckPolicy.standard
    /// The current time. Tests supply their own.
    public var now: @Sendable () -> Date = { Date() }

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
        self.settings = settings
    }

    /// The real thing: URLSession, the Keychain and the app's own folders.
    ///
    /// On a Mac downloads go into the Library folder unless the user chooses another place. On an
    /// iPad they go into the app's Documents folder, which the Files app shows.
    public static func live() -> LibraryEnvironment {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        var environment = LibraryEnvironment(
            http: URLSessionHTTPClient(),
            credentials: KeychainCredentialStore(),
            dataDirectory: support.appending(path: "Scrollkeeper", directoryHint: .isDirectory),
            settings: SettingsStore(suiteName: "")
        )
        #if os(iOS)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            environment.defaultDownloadDirectory = documents
        }
        #endif
        return environment
    }
}

extension LibraryEnvironment {
    /// The launch argument that starts the app in demo mode.
    public static let demoArgument = "-ScrollkeeperDemo"

    /// The environment the app should run in: demo mode when launched with `demoArgument`.
    public static func forLaunch(arguments: [String] = ProcessInfo.processInfo.arguments) -> LibraryEnvironment {
        arguments.contains(demoArgument) ? demo() : live()
    }

    /// An invented library served from inside the app, already signed in, kept in a temporary
    /// folder that starts empty on every launch. Nothing reaches the network or the Keychain.
    public static func demo(downloadDuration: TimeInterval = 8) -> LibraryEnvironment {
        let run = UUID().uuidString
        return LibraryEnvironment(
            http: DemoHTTPClient(downloadDuration: downloadDuration),
            credentials: InMemoryCredentialStore(Credentials(email: "demo@example.com", password: "demo")),
            dataDirectory: FileManager.default.temporaryDirectory.appending(path: "ScrollkeeperDemo-" + run),
            settings: SettingsStore(suiteName: "ScrollkeeperDemo-" + run)
        )
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
    private static let completedFullSyncKey = "hasCompletedFullSync"
    private static let metadataVersionKey = "metadataVersion"
}
