import XCTest
@testable import HomMerge

final class FileCompareToolbarItemTests: XCTestCase {
    func testSystemImageNamesMatchExpectedSFSymbols() {
        XCTAssertEqual(FileCompareToolbarItem.copyRight.systemImages, ["arrow.right"])
        XCTAssertEqual(FileCompareToolbarItem.copyLeft.systemImages, ["arrow.left"])
        XCTAssertEqual(FileCompareToolbarItem.copyRightAndNext.systemImages, ["arrow.right", "chevron.down"])
        XCTAssertEqual(FileCompareToolbarItem.copyLeftAndNext.systemImages, ["arrow.left", "chevron.down"])
        XCTAssertEqual(FileCompareToolbarItem.refresh.systemImages, ["arrow.clockwise"])
        XCTAssertEqual(FileCompareToolbarItem.firstDiff.systemImages, ["chevron.up.2"])
        XCTAssertEqual(FileCompareToolbarItem.previousDiff.systemImages, ["chevron.up"])
        XCTAssertEqual(FileCompareToolbarItem.currentDiff.systemImages, ["scope"])
        XCTAssertEqual(FileCompareToolbarItem.nearestDiff.systemImages, ["text.cursor", "scope"])
        XCTAssertEqual(FileCompareToolbarItem.nextDiff.systemImages, ["chevron.down"])
        XCTAssertEqual(FileCompareToolbarItem.lastDiff.systemImages, ["chevron.down.2"])
    }

    func testTitlesMatchVisibleToolbarLabels() {
        XCTAssertEqual(FileCompareToolbarItem.copyRight.title, "Copy →")
        XCTAssertEqual(FileCompareToolbarItem.copyLeft.title, "← Copy")
        XCTAssertEqual(FileCompareToolbarItem.copyRightAndNext.title, "Copy → and Next")
        XCTAssertEqual(FileCompareToolbarItem.copyLeftAndNext.title, "← Copy and Next")
        XCTAssertEqual(FileCompareToolbarItem.refresh.title, "Refresh")
        XCTAssertEqual(FileCompareToolbarItem.firstDiff.title, "First Diff")
        XCTAssertEqual(FileCompareToolbarItem.previousDiff.title, "Previous Diff")
        XCTAssertEqual(FileCompareToolbarItem.currentDiff.title, "Current Diff")
        XCTAssertEqual(FileCompareToolbarItem.nearestDiff.title, "Nearest Diff")
        XCTAssertEqual(FileCompareToolbarItem.nextDiff.title, "Next Diff")
        XCTAssertEqual(FileCompareToolbarItem.lastDiff.title, "Last Diff")
    }

    func testPreferencesKeyIsStable() {
        XCTAssertEqual(FileCompareToolbarPreferences.usesIconsKey, "fileCompareToolbarUsesIcons")
    }
}
