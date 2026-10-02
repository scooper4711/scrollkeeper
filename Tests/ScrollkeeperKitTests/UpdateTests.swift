import Foundation
@testable import ScrollkeeperKit
import Testing

@Suite struct AppVersionTests {
    @Test(arguments: [
        ("v0.10.0", "0.9.3"), ("1.0.1", "1.0"), ("v2", "1.99.99"), ("0.2.0", "v0.1.0"), ("1.2.3-rc.1", "1.2.2")
    ])
    func newerVersionsCompareGreater(newer: String, older: String) {
        #expect(AppVersion(newer) > AppVersion(older))
        #expect(AppVersion(older) < AppVersion(newer))
    }

    @Test(arguments: [("1.0", "v1.0.0"), ("v0.1.0", "0.1"), ("1.2.3-rc.1", "1.2.3"), ("", "0")])
    func equivalentVersionsAreEqual(first: String, second: String) {
        #expect(AppVersion(first) == AppVersion(second))
        #expect(!(AppVersion(first) < AppVersion(second)))
    }

    @Test func describesItself() {
        #expect(AppVersion(" v0.10.2 ").description == "0.10.2")
        #expect(AppVersion("nonsense").description == "0")
    }
}

@MainActor
@Suite struct AppUpdaterTests {
    private let http = StubHTTPClient()
    private let directory = TemporaryDirectory()

    private func makeUpdater(running version: String = "0.1.0") -> AppUpdater {
        AppUpdater(http: http, currentVersion: version, downloadsDirectory: directory.url)
    }

    private func publish(tag: String, assets: [String] = ["Scrollkeeper-0.2.0.dmg"]) {
        let list = assets.map { ["name": $0, "browser_download_url": "https://downloads.example/" + $0] }
        let release: [String: Any] = ["tag_name": tag, "assets": list]
        http.on("api.github.com/repos/scooper4711/scrollkeeper/releases/latest", json: release)
        http.on("https://downloads.example/", text: "disk image bytes")
    }

    @Test func newerReleaseIsOfferedAndNothingIsDownloadedUntilAccepted() async throws {
        publish(tag: "v0.2.0", assets: ["notes.txt", "Scrollkeeper-0.2.0.dmg"])
        let updater = makeUpdater()

        await updater.checkForUpdate()

        #expect(updater.state == .available(version: "0.2.0"))
        #expect(updater.state.isResult)
        #expect(updater.state.title == "Scrollkeeper 0.2.0 is available")
        #expect(updater.state.message.hasPrefix("Would you like to download it?"))
        #expect(http.count(of: "downloads.example") == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.url.path).isEmpty)
        let request = try #require(http.requests.first)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }

    @Test func acceptedUpdateIsDownloadedToTheDownloadsFolder() async throws {
        publish(tag: "v0.2.0")
        let updater = makeUpdater()
        await updater.checkForUpdate()

        await updater.downloadUpdate()

        let file = directory.url.appending(path: "Scrollkeeper-0.2.0.dmg")
        #expect(updater.state == .downloaded(version: "0.2.0", file: file))
        #expect(try String(contentsOf: file, encoding: .utf8) == "disk image bytes")
        #expect(updater.state.title == "Scrollkeeper 0.2.0 has been downloaded")
        #expect(updater.state.message.contains("Scrollkeeper-0.2.0.dmg"))
    }

    @Test func startDownloadSwitchesToDownloadingAtOnce() async {
        publish(tag: "v0.2.0")
        let updater = makeUpdater()
        updater.startDownload()
        #expect(updater.state == .idle)

        await updater.checkForUpdate()
        updater.startDownload()
        #expect(updater.state == .downloading(version: "0.2.0", fraction: 0))
        updater.dismiss()
        #expect(updater.state.isBusy)

        await updater.downloadTask?.value
        #expect(updater.state.title == "Scrollkeeper 0.2.0 has been downloaded")
    }

    @Test func declinedUpdateDownloadsNothing() async {
        publish(tag: "v0.2.0")
        let updater = makeUpdater()
        await updater.checkForUpdate()

        updater.dismiss()
        await updater.downloadUpdate()

        #expect(updater.state == .idle)
        #expect(http.count(of: "downloads.example") == 0)
    }

    @Test(arguments: ["v0.1.0", "v0.0.9"])
    func sameOrOlderReleaseMeansUpToDate(tag: String) async {
        publish(tag: tag)
        let updater = makeUpdater()

        await updater.checkForUpdate()
        await updater.downloadUpdate()

        #expect(updater.state == .upToDate(version: "0.1.0"))
        #expect(updater.state.message == "You have version 0.1.0, which is the newest.")
        #expect(http.count(of: "downloads.example") == 0)
    }

    @Test func releaseWithoutADiskImageIsReported() async {
        publish(tag: "v0.3.0", assets: ["source.zip"])
        let updater = makeUpdater()

        await updater.checkForUpdate()

        #expect(updater.state == .failed(
            message: "Version 0.3.0 is available, but it has no disk image attached. See the releases page on GitHub."
        ))
    }

    @Test func gitHubErrorsAreReported() async {
        let updater = makeUpdater()
        http.on("api.github.com", text: "rate limited", status: 403)
        await updater.checkForUpdate()
        #expect(updater.state == .failed(message: "Checking for updates failed: GitHub answered with status 403."))

        http.on("api.github.com", text: "<html>")
        await updater.checkForUpdate()
        #expect(updater.state == .failed(
            message: "Checking for updates failed: GitHub's answer was not in the expected form."
        ))
        #expect(updater.state.title == "The update check did not finish")
    }

    @Test func failedDownloadIsReported() async {
        publish(tag: "v0.2.0")
        http.on("https://downloads.example/", text: "gone", status: 404)
        let updater = makeUpdater()
        await updater.checkForUpdate()

        await updater.downloadUpdate()

        guard case let .failed(message) = updater.state else {
            Issue.record("the failed download was not reported")
            return
        }
        #expect(message.hasPrefix("Downloading the update failed: "))
        #expect(message.contains("404"))
    }

    @Test func dismissClearsAResultButNotWorkInProgress() async {
        publish(tag: "v0.1.0")
        let updater = makeUpdater()
        updater.dismiss()
        #expect(updater.state == .idle)

        await updater.checkForUpdate()
        updater.dismiss()
        #expect(updater.state == .idle)
    }

    @Test func statesDescribeThemselves() {
        #expect(UpdateState.idle.title.isEmpty)
        #expect(!UpdateState.idle.isBusy)
        #expect(UpdateState.checking.isBusy)
        #expect(UpdateState.checking.title == "Checking for updates…")
        #expect(UpdateState.checking.message.isEmpty)
        let downloading = UpdateState.downloading(version: "0.2.0", fraction: 0.4)
        #expect(downloading.isBusy)
        #expect(!downloading.isResult)
        #expect(downloading.title == "Downloading Scrollkeeper 0.2.0…")
        #expect(UpdateState.upToDate(version: "1").title == "Scrollkeeper is up to date")
    }

    @Test func liveUpdaterStartsIdle() {
        #expect(AppUpdater.live().state == .idle)
    }
}
