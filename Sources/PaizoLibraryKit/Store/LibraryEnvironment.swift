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

    /// The real thing: URLSession, the Keychain and the user's Library folder.
    public static func live() -> LibraryEnvironment {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
        return LibraryEnvironment(
            http: URLSessionHTTPClient(),
            credentials: KeychainCredentialStore(),
            dataDirectory: support.appending(path: "Paizo Library Manager", directoryHint: .isDirectory),
            settings: SettingsStore(suiteName: "")
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

    private var defaults: UserDefaults {
        (suiteName.isEmpty ? nil : UserDefaults(suiteName: suiteName)) ?? .standard
    }

    private static let downloadDirectoryKey = "downloadDirectoryPath"
    private static let completedFullSyncKey = "hasCompletedFullSync"
}
