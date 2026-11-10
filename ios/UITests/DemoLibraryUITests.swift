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

        // The toolkit's titles come first in the list; the rulebook is further down.
        XCTAssertTrue(app.titleRow("Field Guide Sample Monster Core").exists, "the toolkit's demo titles are missing")
        XCTAssertTrue(app.titleRow("Sample Creature Rulebook").exists, "the demo library didn't load")
        app.buttons["Leave Demo"].tap()
        XCTAssertTrue(app.buttons["Try the Demo Library"].waitForExistence(timeout: 30),
                      "leaving the demo didn't return to signing in")
    }
}
