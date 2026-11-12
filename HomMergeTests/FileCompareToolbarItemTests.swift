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
        let appBundle = Bundle(for: AppViewModel.self)
        XCTAssertEqual(FileCompareToolbarItem.copyRight.title, String(localized: "Copy →", bundle: appBundle))
        XCTAssertEqual(FileCompareToolbarItem.copyLeft.title, String(localized: "← Copy", bundle: appBundle))
        XCTAssertEqual(
            FileCompareToolbarItem.copyRightAndNext.title,
            String(localized: "Copy → and Next", bundle: appBundle)
        )
        XCTAssertEqual(
            FileCompareToolbarItem.copyLeftAndNext.title,
            String(localized: "← Copy and Next", bundle: appBundle)
        )
        XCTAssertEqual(FileCompareToolbarItem.refresh.title, String(localized: "Refresh", bundle: appBundle))
        XCTAssertEqual(FileCompareToolbarItem.firstDiff.title, String(localized: "First Diff", bundle: appBundle))
        XCTAssertEqual(
            FileCompareToolbarItem.previousDiff.title,
            String(localized: "Previous Diff", bundle: appBundle)
        )
        XCTAssertEqual(FileCompareToolbarItem.currentDiff.title, String(localized: "Current Diff", bundle: appBundle))
        XCTAssertEqual(FileCompareToolbarItem.nearestDiff.title, String(localized: "Nearest Diff", bundle: appBundle))
        XCTAssertEqual(FileCompareToolbarItem.nextDiff.title, String(localized: "Next Diff", bundle: appBundle))
        XCTAssertEqual(FileCompareToolbarItem.lastDiff.title, String(localized: "Last Diff", bundle: appBundle))
    }

    func testPreferencesKeyIsStable() {
        XCTAssertEqual(FileCompareToolbarPreferences.usesIconsKey, "fileCompareToolbarUsesIcons")
    }
}
