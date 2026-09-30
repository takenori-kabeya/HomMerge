import DiffEngine
import XCTest
@testable import HomMerge

@MainActor
final class FileCompareCopyCaretTests: XCTestCase {
    func testCopyHunkToRightPlacesCaretAtReplacedStartWithoutPriorCaret() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc\nold3\nd",
            rightText: "a\nnew1\nb\nnew2\nc\nnew3\nd"
        )
        XCTAssertEqual(viewModel.state.navigator.hunkCount, 3)
        XCTAssertNil(viewModel.lastKnownCaretRow)

        let replacedStart = viewModel.state.result!.hunks[1].startRow
        viewModel.selectHunkAndScroll(1)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.copyHunkToRight()

        XCTAssertNil(viewModel.state.navigator.currentIndex)
        XCTAssertEqual(viewModel.lastKnownCaretSide, .right)
        XCTAssertEqual(viewModel.lastKnownCaretRow, replacedStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.side, .right)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.row, replacedStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, true)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, true)
        XCTAssertEqual(viewModel.state.navigator.hunkCount, 2)
    }

    func testGoNextAfterCopyWithoutPriorCaretSelectsHunkAfterReplacedRegion() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc\nold3\nd",
            rightText: "a\nnew1\nb\nnew2\nc\nnew3\nd"
        )
        let replacedStart = viewModel.state.result!.hunks[1].startRow
        let thirdHunkStartBeforeCopy = viewModel.state.result!.hunks[2].startRow
        viewModel.selectHunkAndScroll(1)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.copyHunkToRight()

        XCTAssertNil(viewModel.state.navigator.currentIndex)
        XCTAssertEqual(viewModel.lastKnownCaretRow, replacedStart)

        viewModel.goNextDifference()

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)
        XCTAssertEqual(viewModel.state.currentHunkStartRow, thirdHunkStartBeforeCopy)
        XCTAssertEqual(viewModel.lastKnownCaretRow, thirdHunkStartBeforeCopy)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, false)
        XCTAssertNotEqual(viewModel.state.navigator.currentIndex, 0)
    }

    func testCopyHunkToLeftPlacesCaretOnLeftAtReplacedStart() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        let replacedStart = viewModel.state.result!.hunks[1].startRow
        viewModel.selectHunkAndScroll(1)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.copyHunkToLeft()

        XCTAssertNil(viewModel.state.navigator.currentIndex)
        XCTAssertEqual(viewModel.lastKnownCaretSide, .left)
        XCTAssertEqual(viewModel.lastKnownCaretRow, replacedStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.side, .left)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.row, replacedStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, true)
    }

    func testCopyHunkToRightAndNextPlacesCaretAtNextHunkStartWithoutFocus() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc\nold3\nd",
            rightText: "a\nnew1\nb\nnew2\nc\nnew3\nd"
        )
        let secondHunkStartBeforeCopy = viewModel.state.result!.hunks[1].startRow
        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRightAndNext()

        XCTAssertEqual(viewModel.state.navigator.hunkCount, 2)
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        XCTAssertEqual(viewModel.state.currentHunkStartRow, secondHunkStartBeforeCopy)
        XCTAssertEqual(viewModel.lastKnownCaretRow, secondHunkStartBeforeCopy)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.row, secondHunkStartBeforeCopy)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, false)
    }

    func testCopyHunkToRightAndNextOnLastHunkMatchesCopyThenGoNext() {
        let composed = FileCompareViewModel()
        composed.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        composed.selectHunkAndScroll(1)
        composed.copyHunkToRightAndNext()

        let manual = FileCompareViewModel()
        manual.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        manual.selectHunkAndScroll(1)
        manual.clearPendingCaretLineStartRestore()
        manual.copyHunkToRight()
        manual.goNextDifference()

        XCTAssertEqual(composed.state.navigator.currentIndex, manual.state.navigator.currentIndex)
        XCTAssertEqual(composed.state.currentHunkStartRow, manual.state.currentHunkStartRow)
        XCTAssertEqual(composed.lastKnownCaretRow, manual.lastKnownCaretRow)
        XCTAssertEqual(composed.state.rightText, manual.state.rightText)
    }
}
