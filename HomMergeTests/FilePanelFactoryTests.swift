import AppKit
import XCTest
@testable import HomMerge

final class FilePanelFactoryTests: XCTestCase {
    @MainActor
    func testMakeOpenPanelShowsHiddenFiles() {
        let panel = FilePanelFactory.makeOpenPanel(title: "Open", canChooseDirectories: true)
        XCTAssertTrue(panel.showsHiddenFiles)
        XCTAssertTrue(panel.canChooseFiles)
        XCTAssertTrue(panel.canChooseDirectories)
        XCTAssertFalse(panel.allowsMultipleSelection)
    }

    @MainActor
    func testMakeOpenPanelCanDisableDirectories() {
        let panel = FilePanelFactory.makeOpenPanel(title: "Open File", canChooseDirectories: false)
        XCTAssertTrue(panel.showsHiddenFiles)
        XCTAssertFalse(panel.canChooseDirectories)
    }

    @MainActor
    func testMakeSavePanelShowsHiddenFiles() {
        let panel = FilePanelFactory.makeSavePanel(title: "Save")
        XCTAssertTrue(panel.showsHiddenFiles)
        XCTAssertTrue(panel.canCreateDirectories)
    }
}
