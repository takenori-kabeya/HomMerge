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
        XCTAssertEqual(SessionToolbarItem.openLeft.title, "Open Left…")
        XCTAssertEqual(SessionToolbarItem.openRight.title, "Open Right…")
        XCTAssertEqual(SessionToolbarItem.compare.title, "Compare")
        XCTAssertEqual(SessionToolbarItem.saveLeft.title, "Save Left")
        XCTAssertEqual(SessionToolbarItem.saveRight.title, "Save Right")
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
        XCTAssertEqual(FolderCompareToolbarItem.compareSelectedFiles.title, "Compare Selected Files")
        XCTAssertEqual(FolderCompareToolbarItem.compareSelectedFiles.help, "Compare Selected Files")
        XCTAssertEqual(FolderCompareToolbarItem.copyRight.title, "Copy →")
        XCTAssertEqual(FolderCompareToolbarItem.copyRight.help, "Copy selected item to the right folder")
        XCTAssertEqual(FolderCompareToolbarItem.copyLeft.title, "← Copy")
        XCTAssertEqual(FolderCompareToolbarItem.copyLeft.help, "Copy selected item to the left folder")
        XCTAssertEqual(FolderCompareToolbarItem.delete.title, "Delete")
        XCTAssertEqual(FolderCompareToolbarItem.delete.systemImages, ["trash"])
        XCTAssertEqual(
            FolderCompareToolbarItem.delete.help,
            "Move selected left-only or right-only files to the Trash"
        )
        XCTAssertEqual(FolderCompareToolbarItem.refresh.title, "Refresh")
        XCTAssertEqual(FolderCompareToolbarItem.refresh.help, "Rescan both folders from disk")
    }
}
