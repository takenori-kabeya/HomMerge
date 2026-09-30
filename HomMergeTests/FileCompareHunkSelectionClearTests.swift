import DiffEngine
import XCTest
@testable import HomMerge

@MainActor
final class FileCompareHunkSelectionClearTests: XCTestCase {
    func testSetCaretContextClearsSelectionWhenMovingOutsideAllHunks() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.clearPendingCaretLineStartRestore()
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)

        viewModel.setCaretContext(row: 1, side: .left)
        viewModel.setCaretContext(row: 2, side: .left)

        XCTAssertNil(viewModel.state.navigator.currentIndex)
    }

    func testSetCaretContextKeepsSelectionWhenMovingInsideAHunk() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.setCaretContext(row: 1, side: .left)
        viewModel.setCaretContext(row: 3, side: .left)

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
    }

    func testSetCaretContextDoesNotClearWhenSameHunkStartRowIsRepublished() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(1)
        viewModel.clearPendingCaretLineStartRestore()
        let hunkStart = viewModel.state.currentHunkStartRow
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)
        XCTAssertEqual(viewModel.lastKnownCaretRow, hunkStart)

        viewModel.setCaretContext(row: hunkStart, side: .left)

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)
    }
}
