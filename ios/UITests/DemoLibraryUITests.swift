import XCTest

/// The demo library from the sign-in screen, as App Review reaches it (#44): no launch argument, no account.
final class DemoLibraryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheDemoLibraryOpensFromTheSignInScreenAndCanBeLeft() {
        let app = XCUIApplication()
        app.launchArguments = ["-viewMode", "list"]
        app.launch()
        let tryDemo = app.buttons["Try the Demo Library"]
        XCTAssertTrue(tryDemo.waitForExistence(timeout: 30), "the sign-in screen offers no demo")

        tryDemo.tap()

        XCTAssertTrue(app.staticTexts["Sample Creature Rulebook"].waitForExistence(timeout: 30),
                      "the demo library didn't load")
        XCTAssertTrue(app.staticTexts["Field Guide Sample Monster Core"].exists,
                      "the toolkit's demo titles are missing")
        app.buttons["Leave Demo"].tap()
        XCTAssertTrue(app.buttons["Try the Demo Library"].waitForExistence(timeout: 30),
                      "leaving the demo didn't return to signing in")
    }
}
