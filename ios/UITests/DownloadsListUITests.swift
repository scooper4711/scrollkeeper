import XCTest

/// Drives the iPad app in demo mode, where the library is invented and downloads take seconds.
final class DownloadsListUITests: XCTestCase {
    private let listFooter = "Up to 5 files download at a time; the rest wait."

    override func setUp() {
        continueAfterFailure = false
    }

    /// Long enough that a download is still running whenever a slow simulator gets around to looking.
    private let unhurried = 300

    /// Launches the demo library, whose downloads take eight seconds unless told otherwise.
    @MainActor
    private func launchDemo(downloadSeconds: Int = 8) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ScrollkeeperDemo", "-viewMode", "list", "-demoDownloadSeconds", "\(downloadSeconds)"]
        app.launch()
        XCTAssertTrue(app.titleRow("Sample Creature Rulebook").exists, "library did not load")
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
        let app = launchDemo(downloadSeconds: unhurried)
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
        let app = launchDemo(downloadSeconds: unhurried)
        startDownload(of: "Sample Creature Rulebook", in: app)
        app.buttons["downloads-button"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Cancel All"].waitForExistence(timeout: 5))

        app.buttons["Cancel All"].tap()

        XCTAssertTrue(app.staticTexts["Nothing is downloading."].waitForExistence(timeout: 5))
    }

    /// Starts a download through the long-press menu of a title in the list.
    @MainActor
    private func startDownload(of title: String, in app: XCUIApplication) {
        app.titleRow(title).press(forDuration: 1.2)
        let download = app.buttons["Download"].firstMatch
        XCTAssertTrue(download.waitForExistence(timeout: 5), "the quick-action menu did not appear")
        download.tap()
    }
}

extension XCUIApplication {
    /// The row of a title in the library list, scrolled into view: the list builds only the rows on screen, and
    /// the demo library has more titles than fit on an iPad. Gives up after `timeout` seconds, which also have to
    /// cover the library loading on a slow simulator.
    func titleRow(_ title: String, timeout: TimeInterval = 90) -> XCUIElement {
        let row = staticTexts[title]
        let deadline = Date().addingTimeInterval(timeout)
        while !row.waitForExistence(timeout: 1), Date() < deadline {
            scrollDownWithoutCoasting()
        }
        return row
    }

    /// Moves the list on by a third of the screen and holds it there. A swipe lets the list coast, and a list
    /// that coasts past the row has dropped it again by the time the row is looked for.
    private func scrollDownWithoutCoasting() {
        let lower = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let upper = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        lower.press(forDuration: 0.1, thenDragTo: upper, withVelocity: .default, thenHoldForDuration: 0.3)
    }
}
