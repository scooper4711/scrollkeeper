import XCTest

/// The `scrollkeeper` link another toolkit app opens to bring Scrollkeeper forward (app-handoff 2.9).
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
}
