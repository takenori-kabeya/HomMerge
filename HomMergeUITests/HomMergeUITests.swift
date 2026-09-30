import XCTest

/// UI smoke tests that launch the HomMerge app under XCTest.
final class HomMergeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsMainWindow() throws {
        let app = XCUIApplication()
        app.launch()

        let windows = app.windows
        XCTAssertTrue(
            windows.firstMatch.waitForExistence(timeout: 5),
            "HomMerge should show at least one window on launch"
        )
    }
}
