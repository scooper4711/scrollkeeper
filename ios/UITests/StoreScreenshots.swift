import XCTest

/// The App Store's pictures, from the app's demo content: tabletop-kit's `store-screenshots.sh`.
/// Skipped unless the script names the folder to save into.
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var folder: URL!

    override func setUpWithError() throws {
        let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? ""
        try XCTSkipIf(path.isEmpty, "Set SCREENSHOT_DIR to make the store screenshots.")
        folder = URL(fileURLWithPath: path)
        continueAfterFailure = false
        app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testLibrary() throws {
        app.launchArguments = ["-ScrollkeeperDemo", "-viewMode", "covers"]
        app.launch()
        let title = app.staticTexts["Sample Adventure: The Lighthouse"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30), app.debugDescription)
        // The covers come from the network.
        Thread.sleep(forTimeInterval: 10)
        try save("1-library")
        title.tap()
        XCTAssertTrue(app.links["View on paizo.com"].waitForExistence(timeout: 10), app.debugDescription)
        try save("2-details")
    }

    /// The library as a list, which has room for a title's author and type beside its name.
    @MainActor
    func testList() throws {
        app.launchArguments = ["-ScrollkeeperDemo", "-viewMode", "list"]
        app.launch()
        let title = app.staticTexts["Sample Adventure: The Lighthouse"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30), app.debugDescription)
        try save("3-list")
    }

    private func save(_ name: String) throws {
        Thread.sleep(forTimeInterval: 1.5)
        let file = folder.appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
    }
}
