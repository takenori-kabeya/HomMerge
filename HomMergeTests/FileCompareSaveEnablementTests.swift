import DiffEngine
import XCTest
@testable import HomMerge

@MainActor
final class FileCompareSaveEnablementTests: XCTestCase {
    func testCanSaveFollowsOnlyUncommittedSide() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(leftText: "a", rightText: "b")

        XCTAssertFalse(viewModel.canSaveLeft)
        XCTAssertFalse(viewModel.canSaveRight)

        viewModel.setUncommittedEditSides([.left])
        XCTAssertTrue(viewModel.canSaveLeft)
        XCTAssertFalse(viewModel.canSaveRight)
        XCTAssertTrue(viewModel.isEditingPane)

        viewModel.setUncommittedEditSides([.right])
        XCTAssertFalse(viewModel.canSaveLeft)
        XCTAssertTrue(viewModel.canSaveRight)

        viewModel.setUncommittedEditSides([.left, .right])
        XCTAssertTrue(viewModel.canSaveLeft)
        XCTAssertTrue(viewModel.canSaveRight)

        viewModel.setUncommittedEditSides([])
        XCTAssertFalse(viewModel.canSaveLeft)
        XCTAssertFalse(viewModel.canSaveRight)
        XCTAssertFalse(viewModel.isEditingPane)
    }

    func testCanSaveUsesCommittedDirtyFlagsPerSide() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(leftText: "a", rightText: "b")
        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRight()

        XCTAssertFalse(viewModel.canSaveLeft)
        XCTAssertTrue(viewModel.canSaveRight)
    }
}
