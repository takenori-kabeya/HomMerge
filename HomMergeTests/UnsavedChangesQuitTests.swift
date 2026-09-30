import AppKit
import XCTest
@testable import HomMerge

@MainActor
final class UnsavedChangesQuitTests: XCTestCase {
    func testAppViewModelCountsUnsavedTabsAcrossTabs() {
        let appModel = AppViewModel()
        XCTAssertEqual(appModel.unsavedFileChangeTabCount, 0)

        markFileCompareDirty(in: appModel.tabs[0].session)
        XCTAssertEqual(appModel.unsavedFileChangeTabCount, 1)

        let secondTab = appModel.addTab(select: false)
        markFileCompareDirty(in: secondTab.session)
        XCTAssertEqual(appModel.unsavedFileChangeTabCount, 2)
    }

    func testSessionRegistryAggregatesUnsavedTabsAcrossWindows() {
        let registry = SessionRegistry.shared
        let firstWindow = AppViewModel()
        let secondWindow = AppViewModel()
        let firstNSWindow = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        let secondNSWindow = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)

        registry.register(firstWindow, window: firstNSWindow)
        registry.register(secondWindow, window: secondNSWindow)
        defer {
            registry.unregister(firstWindow)
            registry.unregister(secondWindow)
        }

        XCTAssertEqual(registry.unsavedFileChangeTabCount, 0)
        XCTAssertEqual(registry.windowsWithUnsavedFileChanges, 0)

        markFileCompareDirty(in: firstWindow.tabs[0].session)
        XCTAssertEqual(registry.unsavedFileChangeTabCount, 1)
        XCTAssertEqual(registry.windowsWithUnsavedFileChanges, 1)

        markFileCompareDirty(in: secondWindow.tabs[0].session)
        XCTAssertEqual(registry.unsavedFileChangeTabCount, 2)
        XCTAssertEqual(registry.windowsWithUnsavedFileChanges, 2)
    }

    private func markFileCompareDirty(in session: CompareSessionViewModel) {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(leftText: "alpha", rightText: "beta")
        session.leftURL = URL(fileURLWithPath: "/tmp/left.txt")
        session.rightURL = URL(fileURLWithPath: "/tmp/right.txt")
        session.phase = .files(viewModel)
        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRight()
        XCTAssertTrue(session.hasUnsavedFileChanges)
    }
}
