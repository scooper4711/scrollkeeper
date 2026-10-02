import Foundation
import Observation

/// Why an update check did not finish.
public enum UpdateError: Error, Equatable, LocalizedError {
    case http(status: Int)
    case unreadableAnswer
    case noDiskImage(version: String)

    public var errorDescription: String? {
        switch self {
        case let .http(status):
            "Checking for updates failed: GitHub answered with status \(status)."
        case .unreadableAnswer:
            "Checking for updates failed: GitHub's answer was not in the expected form."
        case let .noDiskImage(version):
            "Version \(version) is available, but it has no disk image attached. "
                + "See the releases page on GitHub."
        }
    }
}

/// Where an update check stands.
public enum UpdateState: Equatable, Sendable {
    case idle
    case checking
    case upToDate(version: String)
    /// A newer version exists; nothing has been downloaded.
    case available(version: String)
    case downloading(version: String, fraction: Double)
    case downloaded(version: String, file: URL)
    case failed(message: String)

    /// True while the check or the download is under way.
    public var isBusy: Bool {
        switch self {
        case .checking, .downloading: true
        default: false
        }
    }

    /// True when there is something to tell or ask the user.
    public var isResult: Bool {
        switch self {
        case .upToDate, .available, .downloaded, .failed: true
        default: false
        }
    }

    public var title: String {
        switch self {
        case .idle: ""
        case .checking: "Checking for updates…"
        case .upToDate: "Scrollkeeper is up to date"
        case let .available(version): "Scrollkeeper \(version) is available"
        case let .downloading(version, _): "Downloading Scrollkeeper \(version)…"
        case let .downloaded(version, _): "Scrollkeeper \(version) has been downloaded"
        case .failed: "The update check did not finish"
        }
    }

    public var message: String {
        switch self {
        case .idle, .checking, .downloading: ""
        case let .upToDate(version):
            "You have version \(version), which is the newest."
        case .available:
            "Would you like to download it? The disk image goes into your Downloads folder."
        case let .downloaded(_, file):
            "The disk image \(file.lastPathComponent) is in your Downloads folder. Open it, quit "
                + "Scrollkeeper, and drag the new version to Applications."
        case let .failed(message):
            message
        }
    }
}

/// The part of GitHub's description of a release that the updater reads.
private struct GitHubRelease: Decodable {
    let tag: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tag = "tag_name"
        case assets
    }

    var version: AppVersion { AppVersion(tag) }

    var diskImage: GitHubAsset? { assets.first { $0.name.lowercased().hasSuffix(".dmg") } }
}

private struct GitHubAsset: Decodable {
    let name: String
    let address: String

    enum CodingKeys: String, CodingKey {
        case name
        case address = "browser_download_url"
    }
}

/// Checks GitHub for a newer release and, when the user agrees, downloads its disk image.
@MainActor
@Observable
public final class AppUpdater {
    public static let latestReleaseAddress = "https://api.github.com/repos/scooper4711/scrollkeeper/releases/latest"

    public private(set) var state = UpdateState.idle

    private let http: HTTPClient
    private let currentVersion: AppVersion
    private let downloadsDirectory: URL
    /// The disk image of the release that was found, kept until the user decides.
    private var offered: GitHubAsset?
    private(set) var downloadTask: Task<Void, Never>?

    public init(http: HTTPClient, currentVersion: String, downloadsDirectory: URL) {
        self.http = http
        self.currentVersion = AppVersion(currentVersion)
        self.downloadsDirectory = downloadsDirectory
    }

    /// The updater for the running app: its bundle version and the user's Downloads folder.
    public static func live() -> AppUpdater {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return AppUpdater(http: URLSessionHTTPClient(), currentVersion: version ?? "0", downloadsDirectory: downloads)
    }

    /// Asks GitHub for the latest release and reports whether it is newer. Nothing is downloaded.
    public func checkForUpdate() async {
        guard !state.isBusy else { return }
        state = .checking
        offered = nil
        do {
            let release = try await fetchLatestRelease()
            guard release.version > currentVersion else {
                state = .upToDate(version: currentVersion.description)
                return
            }
            guard let diskImage = release.diskImage else {
                throw UpdateError.noDiskImage(version: release.version.description)
            }
            offered = diskImage
            state = .available(version: release.version.description)
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Downloads the disk image of the version that was offered, into the Downloads folder.
    public func downloadUpdate() async {
        guard let pending = beginDownload() else { return }
        await perform(pending)
    }

    /// Starts the download without waiting for it. The state changes to downloading at once,
    /// so a view that asked the question can close.
    public func startDownload() {
        guard let pending = beginDownload() else { return }
        downloadTask = Task { await perform(pending) }
    }

    private struct PendingDownload {
        let version: String
        let name: String
        let source: URL
    }

    private func beginDownload() -> PendingDownload? {
        guard case let .available(version) = state, let asset = offered, let source = URL(string: asset.address) else {
            return nil
        }
        state = .downloading(version: version, fraction: 0)
        return PendingDownload(version: version, name: asset.name, source: source)
    }

    private func perform(_ pending: PendingDownload) async {
        let version = pending.version
        let source = pending.source
        let destination = downloadsDirectory.appending(path: pending.name)
        do {
            try await http.download(URLRequest(url: source), to: destination) { [weak self] fraction in
                Task { @MainActor in self?.reportProgress(fraction, version: version) }
            }
            state = .downloaded(version: version, file: destination)
        } catch {
            state = .failed(message: "Downloading the update failed: \(error.localizedDescription)")
        }
    }

    /// Clears a result once the user has seen it or declined the download.
    public func dismiss() {
        if state.isResult {
            state = .idle
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease {
        guard let url = URL(string: Self.latestReleaseAddress) else { throw UpdateError.unreadableAnswer }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let response = try await http.send(request)
        guard response.isSuccess else { throw UpdateError.http(status: response.statusCode) }
        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: response.data) else {
            throw UpdateError.unreadableAnswer
        }
        return release
    }

    /// Progress arrives from the network's own queue and may trail the end of the download.
    private func reportProgress(_ fraction: Double, version: String) {
        if case .downloading = state {
            state = .downloading(version: version, fraction: fraction)
        }
    }
}
