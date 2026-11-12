import XCTest
@testable import HomMerge

final class SessionToolbarItemTests: XCTestCase {
    func testSessionSystemImagesMatchExpectedSFSymbols() {
        XCTAssertEqual(SessionToolbarItem.openLeft.systemImages, ["arrow.left", "folder"])
        XCTAssertEqual(SessionToolbarItem.openRight.systemImages, ["folder", "arrow.right"])
        XCTAssertEqual(SessionToolbarItem.compare.systemImages, ["arrow.left.arrow.right"])
        XCTAssertEqual(SessionToolbarItem.saveLeft.systemImages, ["arrow.left", "square.and.arrow.down"])
        XCTAssertEqual(SessionToolbarItem.saveRight.systemImages, ["square.and.arrow.down", "arrow.right"])
    }

    func testSessionCompareUsesSingleSymbol() {
        XCTAssertEqual(SessionToolbarItem.compare.systemImages.count, 1)
    }

    func testSessionTitlesMatchVisibleToolbarLabels() {
        let appBundle = Bundle(for: AppViewModel.self)
        XCTAssertEqual(SessionToolbarItem.openLeft.title, String(localized: "Open Left…", bundle: appBundle))
        XCTAssertEqual(SessionToolbarItem.openRight.title, String(localized: "Open Right…", bundle: appBundle))
        XCTAssertEqual(SessionToolbarItem.compare.title, String(localized: "Compare", bundle: appBundle))
        XCTAssertEqual(SessionToolbarItem.saveLeft.title, String(localized: "Save Left", bundle: appBundle))
        XCTAssertEqual(SessionToolbarItem.saveRight.title, String(localized: "Save Right", bundle: appBundle))
    }

    func testFolderCompareSystemImagesMatchExpectedSFSymbols() {
        XCTAssertEqual(
            FolderCompareToolbarItem.compareSelectedFiles.systemImages,
            ["doc.on.doc", "arrow.left.arrow.right"]
        )
        XCTAssertEqual(FolderCompareToolbarItem.copyRight.systemImages, ["arrow.right"])
        XCTAssertEqual(FolderCompareToolbarItem.copyLeft.systemImages, ["arrow.left"])
        XCTAssertEqual(FolderCompareToolbarItem.refresh.systemImages, ["arrow.clockwise"])
    }

    func testFolderCompareTitlesAndHelp() {
        let appBundle = Bundle(for: AppViewModel.self)
        XCTAssertEqual(
            FolderCompareToolbarItem.compareSelectedFiles.title,
            String(localized: "Compare Selected Files", bundle: appBundle)
        )
        XCTAssertEqual(
            FolderCompareToolbarItem.compareSelectedFiles.help,
            String(localized: "Compare Selected Files", bundle: appBundle)
        )
        XCTAssertEqual(FolderCompareToolbarItem.copyRight.title, String(localized: "Copy →", bundle: appBundle))
        XCTAssertEqual(
            FolderCompareToolbarItem.copyRight.help,
            String(localized: "Copy selected item to the right folder", bundle: appBundle)
        )
        XCTAssertEqual(FolderCompareToolbarItem.copyLeft.title, String(localized: "← Copy", bundle: appBundle))
        XCTAssertEqual(
            FolderCompareToolbarItem.copyLeft.help,
            String(localized: "Copy selected item to the left folder", bundle: appBundle)
        )
        XCTAssertEqual(FolderCompareToolbarItem.delete.title, String(localized: "Delete", bundle: appBundle))
        XCTAssertEqual(FolderCompareToolbarItem.delete.systemImages, ["trash"])
        XCTAssertEqual(
            FolderCompareToolbarItem.delete.help,
            String(localized: "Move selected left-only or right-only files to the Trash", bundle: appBundle)
        )
        XCTAssertEqual(FolderCompareToolbarItem.refresh.title, String(localized: "Refresh", bundle: appBundle))
        XCTAssertEqual(
            FolderCompareToolbarItem.refresh.help,
            String(localized: "Rescan both folders from disk", bundle: appBundle)
        )
    }
}
