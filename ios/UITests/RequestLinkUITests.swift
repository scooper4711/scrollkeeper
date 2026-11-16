import XCTest

/// The `scrollkeeper` links another toolkit app opens to bring Scrollkeeper forward, or to have it download a
/// title (app-handoff 2.9).
final class RequestLinkUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheLinkBringsTheAppForwardInTheWindowItHas() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ScrollkeeperDemo"]
        app.launch()
        let scope = app.staticTexts["Downloaded"].firstMatch
        XCTAssertTrue(scope.waitForExistence(timeout: 30), "the sidebar didn't appear")
        scope.tap()
        let library = app.navigationBars["Downloaded"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), app.debugDescription)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10), "the app didn't leave the foreground")

        XCUIDevice.shared.system.open(try XCTUnwrap(URL(string: "scrollkeeper://")))

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10), "the link didn't bring the app forward")
        // A window opened for the link would show All Titles, as a new one does.
        XCTAssertTrue(library.waitForExistence(timeout: 10), "the link opened a window of its own")
    }

    func testADownloadRequestShowsTheTitleAndDownloadsIt() throws {
        let app = launchDemo(downloadSeconds: 300)

        XCUIDevice.shared.system.open(try XCTUnwrap(URL(string: "scrollkeeper://download?sku=DEMO1003E&app=mapsmith")))

        let downloads = app.buttons["downloads-button"].firstMatch
        let isDownloading = NSPredicate(format: "label == %@", "Downloads, 1 in progress")
        let started = expectation(for: isDownloading, evaluatedWith: downloads)
        wait(for: [started], timeout: 30)
        XCTAssertTrue(app.staticTexts["Sample Creature Rulebook"].firstMatch.exists, "the title isn't shown")
    }

    func testARequestFromAnUnknownAppIsRefused() throws {
        let app = launchDemo()

        XCUIDevice.shared.system.open(try XCTUnwrap(URL(string: "scrollkeeper://download?sku=DEMO1003E&app=other")))

        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10), "no alert said why")
        XCTAssertEqual(app.buttons["downloads-button"].firstMatch.label, "Downloads")
    }

    private func launchDemo(downloadSeconds: Int = 8) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ScrollkeeperDemo", "-demoDownloadSeconds", "\(downloadSeconds)"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Downloaded"].firstMatch.waitForExistence(timeout: 30), "the library didn't load")
        return app
    }
}
