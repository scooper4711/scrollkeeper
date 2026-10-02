import XCTest

/// Drives the iPad app in demo mode, where the library is invented and downloads take seconds.
final class DownloadsListUITests: XCTestCase {
    private let listFooter = "Up to 5 files download at a time; the rest wait."

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchDemo() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ScrollkeeperDemo", "-viewMode", "list"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Sample Creature Rulebook"].waitForExistence(timeout: 30), "library did not load")
        return app
    }

    @MainActor
    func testDownloadsListOpensWhenNothingIsDownloading() {
        let app = launchDemo()

        app.buttons["downloads-button"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts[listFooter].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nothing is downloading."].exists)
    }

    @MainActor
    func testDownloadsListOpensWhileADownloadIsRunning() {
        let app = launchDemo()
        startDownload(of: "Sample Creature Rulebook", in: app)

        let downloads = app.buttons["downloads-button"].firstMatch
        XCTAssertTrue(downloads.waitForExistence(timeout: 5))
        XCTAssertEqual(downloads.label, "Downloads, 1 in progress")
        downloads.tap()

        XCTAssertTrue(app.staticTexts[listFooter].waitForExistence(timeout: 5), "the downloads list did not open")
        XCTAssertTrue(app.staticTexts["Sample Creature Rulebook PDF"].exists, "the running download is not listed")
        XCTAssertTrue(app.buttons["Cancel All"].isEnabled)
    }

    @MainActor
    func testDownloadsListStaysOpenWhenADownloadFinishes() {
        let app = launchDemo()
        startDownload(of: "Sample Creature Rulebook", in: app)
        app.buttons["downloads-button"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts[listFooter].waitForExistence(timeout: 5))

        // The demo download takes eight seconds; the list must still be there afterwards.
        XCTAssertTrue(app.staticTexts["Nothing is downloading."].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts[listFooter].exists, "the downloads list closed when the download finished")
    }

    @MainActor
    func testRunningDownloadCanBeCanceledFromTheList() {
        let app = launchDemo()
        startDownload(of: "Sample Creature Rulebook", in: app)
        app.buttons["downloads-button"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Cancel All"].waitForExistence(timeout: 5))

        app.buttons["Cancel All"].tap()

        XCTAssertTrue(app.staticTexts["Nothing is downloading."].waitForExistence(timeout: 5))
    }

    /// Starts a download through the long-press menu of a title in the list.
    @MainActor
    private func startDownload(of title: String, in app: XCUIApplication) {
        app.staticTexts[title].press(forDuration: 1.2)
        let download = app.buttons["Download"].firstMatch
        XCTAssertTrue(download.waitForExistence(timeout: 5), "the quick-action menu did not appear")
        download.tap()
    }
}
