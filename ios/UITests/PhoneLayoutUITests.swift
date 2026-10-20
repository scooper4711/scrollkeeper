import XCTest

/// On an iPhone the bar has the filters, the downloads and a menu with the rest; a title opens its details.
final class PhoneLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Only an iPhone has the narrow bar.")
        continueAfterFailure = false
    }

    /// Launched without a view mode, since a launch argument would outrank the one the menu saves.
    @MainActor
    func testTheMenuSwitchesBetweenTheCoversAndTheList() {
        launchDemo(viewMode: nil)

        choose("Covers")
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "the covers are not a list")
        choose("List")
        XCTAssertTrue(row.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testTheColumnsShowAsTheList() {
        launchDemo(viewMode: "columns")
        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    func testChoosingATitleOpensItsDetails() {
        launchDemo(viewMode: "covers")
        app.staticTexts["Sample Adventure: The Lighthouse"].firstMatch.tap()
        XCTAssertTrue(app.buttons["View on paizo.com"].waitForExistence(timeout: 5), app.debugDescription)
    }

    @MainActor
    private func launchDemo(viewMode: String?) {
        app = XCUIApplication()
        app.launchArguments = ["-ScrollkeeperDemo"] + (viewMode.map { ["-viewMode", $0] } ?? [])
        app.launch()
        XCTAssertTrue(app.staticTexts["Sample Adventure: The Lighthouse"].waitForExistence(timeout: 30),
                      "library did not load")
    }

    @MainActor
    private func choose(_ viewMode: String) {
        app.buttons["More"].firstMatch.tap()
        let item = app.buttons[viewMode].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), app.debugDescription)
        item.tap()
    }
}
