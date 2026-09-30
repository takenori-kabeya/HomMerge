import XCTest
@testable import HomMerge

@MainActor
final class OpenFileCompareTabInsertionTests: XCTestCase {
    func testOpenFileCompareInsertsImmediatelyAfterSelectedTab() {
        let appModel = AppViewModel()
        let folderTab = appModel.tabs[0]
        folderTab.session.leftURL = URL(fileURLWithPath: "/tmp/folder-left")
        folderTab.session.rightURL = URL(fileURLWithPath: "/tmp/folder-right")
        folderTab.session.phase = .folders(FolderCompareViewModel())

        let otherTab = appModel.addTab(select: false)
        otherTab.session.restorePaths(
            left: URL(fileURLWithPath: "/tmp/other-left"),
            right: URL(fileURLWithPath: "/tmp/other-right")
        )
        appModel.selectTab(folderTab.id)

        let left = URL(fileURLWithPath: "/tmp/file-left.txt")
        let right = URL(fileURLWithPath: "/tmp/file-right.txt")
        appModel.openFileCompareInNewTab(left: left, right: right)

        XCTAssertEqual(appModel.tabs.count, 3)
        XCTAssertEqual(appModel.tabs[0].id, folderTab.id)
        XCTAssertEqual(appModel.tabs[2].id, otherTab.id)
        XCTAssertEqual(appModel.selectedTabID, appModel.tabs[1].id)
        XCTAssertEqual(appModel.tabs[1].session.leftURL, left)
        XCTAssertEqual(appModel.tabs[1].session.rightURL, right)
    }

    func testOpenFileCompareOpensMultipleFilesInOrderAfterSelectedTab() {
        let appModel = AppViewModel()
        let folderTab = appModel.tabs[0]
        folderTab.session.phase = .folders(FolderCompareViewModel())

        let otherTab = appModel.addTab(select: false)
        appModel.selectTab(folderTab.id)

        let firstLeft = URL(fileURLWithPath: "/tmp/first-left.txt")
        let firstRight = URL(fileURLWithPath: "/tmp/first-right.txt")
        let secondLeft = URL(fileURLWithPath: "/tmp/second-left.txt")
        let secondRight = URL(fileURLWithPath: "/tmp/second-right.txt")

        appModel.openFileCompareInNewTab(left: firstLeft, right: firstRight)
        appModel.openFileCompareInNewTab(left: secondLeft, right: secondRight)

        XCTAssertEqual(appModel.tabs.count, 4)
        XCTAssertEqual(appModel.tabs[0].id, folderTab.id)
        XCTAssertEqual(appModel.tabs[1].session.leftURL, firstLeft)
        XCTAssertEqual(appModel.tabs[2].session.leftURL, secondLeft)
        XCTAssertEqual(appModel.tabs[3].id, otherTab.id)
        XCTAssertEqual(appModel.selectedTabID, appModel.tabs[2].id)
    }

    func testOpenFileCompareAppendsWhenSelectedTabIsLast() {
        let appModel = AppViewModel()
        let firstTab = appModel.tabs[0]
        let lastTab = appModel.addTab(select: true)

        let left = URL(fileURLWithPath: "/tmp/last-left.txt")
        let right = URL(fileURLWithPath: "/tmp/last-right.txt")
        appModel.openFileCompareInNewTab(left: left, right: right)

        XCTAssertEqual(appModel.tabs.count, 3)
        XCTAssertEqual(appModel.tabs[0].id, firstTab.id)
        XCTAssertEqual(appModel.tabs[1].id, lastTab.id)
        XCTAssertEqual(appModel.tabs[2].session.leftURL, left)
        XCTAssertEqual(appModel.selectedTabID, appModel.tabs[2].id)
    }
}
