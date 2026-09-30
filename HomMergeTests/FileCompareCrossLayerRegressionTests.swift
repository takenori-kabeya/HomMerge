import DiffEngine
import XCTest
@testable import HomMerge

/// ViewModel 横断契約: DiffEngine の選択とキャレット／クリア／スクロールの組み合わせ。
@MainActor
final class FileCompareCrossLayerRegressionTests: XCTestCase {
    // MARK: - Diff 移動 × キャレット × hunk 外クリア

    func testGoNextDifferenceMovesCaretToHunkStartAndRequestsResignFocus() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.setCaretContext(row: 1, side: .left)

        viewModel.goNextDifference()

        let hunkStart = viewModel.state.currentHunkStartRow
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)
        XCTAssertEqual(viewModel.lastKnownCaretRow, hunkStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.row, hunkStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.side, .left)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, false)
        XCTAssertEqual(viewModel.scrollToRow, hunkStart)
    }

    func testGoNextDifferenceThenCaretOutsideAllHunksClearsSelection() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.setCaretContext(row: 1, side: .left)
        viewModel.goNextDifference()
        viewModel.clearPendingCaretLineStartRestore()
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)

        viewModel.setCaretContext(row: 0, side: .left)

        XCTAssertNil(viewModel.state.navigator.currentIndex)
    }

    func testGoFirstAndLastDifferenceMoveCaretToHunkStart() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.setCaretContext(row: 2, side: .left)

        viewModel.goLastDifference()
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)
        XCTAssertEqual(viewModel.lastKnownCaretRow, viewModel.state.currentHunkStartRow)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, false)

        viewModel.goFirstDifference()
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        XCTAssertEqual(viewModel.lastKnownCaretRow, viewModel.state.currentHunkStartRow)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, false)
    }

    func testGoNextOnLastSelectedHunkKeepsSelectionAndCaretAtHunkStart() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(1)
        let hunkStart = viewModel.state.currentHunkStartRow
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.setCaretContext(row: 3, side: .left)

        viewModel.goNextDifference()

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)
        XCTAssertEqual(viewModel.lastKnownCaretRow, 3)
        XCTAssertEqual(hunkStart, 3)
    }

    func testGoNextWhenUnselectedPastLastHunkMovesCaretToNearestHunkStart() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        XCTAssertNil(viewModel.state.navigator.currentIndex)
        viewModel.setCaretContext(row: 4, side: .left)

        viewModel.goNextDifference()

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)
        XCTAssertEqual(viewModel.lastKnownCaretRow, viewModel.state.currentHunkStartRow)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, false)
    }

    func testSelectNearestHunkMovesCaretToHunkStart() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(1)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.setCaretContext(row: 1, side: .left)

        viewModel.selectNearestHunkToCaret()

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        XCTAssertEqual(viewModel.lastKnownCaretRow, viewModel.state.currentHunkStartRow)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, false)
    }

    func testSelectHunkAndScrollPlacesCaretAtHunkStartWithoutFocus() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.setCaretContext(row: 0, side: .right)

        viewModel.selectHunkAndScroll(1)

        let hunkStart = viewModel.state.currentHunkStartRow
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 1)
        XCTAssertEqual(viewModel.lastKnownCaretRow, hunkStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.row, hunkStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.side, .right)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, false)
    }

    // MARK: - Copy and Next × キャレット再通知

    func testCopyAndNextKeepsSelectionWhenCaretRestoreRepublishesSameRow() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc\nold3\nd",
            rightText: "a\nnew1\nb\nnew2\nc\nnew3\nd"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRightAndNext()
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        let caretRow = viewModel.lastKnownCaretRow
        XCTAssertNotNil(caretRow)

        viewModel.setCaretContext(row: caretRow, side: .right)

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
    }

    func testCopyAndNextKeepsSelectionWhenStaleOppositeSideCaretArrivesDuringRestore() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc\nold3\nd",
            rightText: "a\nnew1\nb\nnew2\nc\nnew3\nd"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.setCaretContext(row: 1, side: .left)
        viewModel.copyHunkToRightAndNext()
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        XCTAssertNotNil(viewModel.pendingCaretLineStartRestore)

        // Toolbar click / textDidEndEditing can republish the pre-copy pane caret before restore applies.
        viewModel.setCaretContext(row: 1, side: .left)

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        XCTAssertNotNil(viewModel.pendingCaretLineStartRestore)
    }

    // MARK: - Undo × 選択 × キャレット

    func testUndoAfterCopyRestoresSelectionWithoutMovingCaret() {
        let viewModel = FileCompareViewModel()
        viewModel.undoManager.groupsByEvent = false
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.setCaretContext(row: 1, side: .left)
        viewModel.copyHunkToRight()
        let caretAfterCopy = viewModel.lastKnownCaretRow
        XCTAssertEqual(caretAfterCopy, 1)
        XCTAssertNil(viewModel.state.navigator.currentIndex)

        viewModel.undoManager.undo()

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        XCTAssertEqual(viewModel.lastKnownCaretRow, caretAfterCopy)
        XCTAssertEqual(viewModel.scrollToRow, viewModel.state.currentHunkStartRow)
        XCTAssertEqual(viewModel.state.rightText, "a\nnew1\nb\nnew2\nc")
    }

    func testRedoAfterUndoCopyRestoresClearedSelectionAndKeepsCaret() {
        let viewModel = FileCompareViewModel()
        viewModel.undoManager.groupsByEvent = false
        viewModel.seedComparison(
            leftText: "a\nold1\nb\nold2\nc",
            rightText: "a\nnew1\nb\nnew2\nc"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRight()
        let caretAfterCopy = viewModel.lastKnownCaretRow
        viewModel.undoManager.undo()
        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)

        viewModel.undoManager.redo()

        XCTAssertNil(viewModel.state.navigator.currentIndex)
        XCTAssertEqual(viewModel.lastKnownCaretRow, caretAfterCopy)
        XCTAssertEqual(viewModel.state.rightText, "a\nold1\nb\nnew2\nc")
    }

    // MARK: - Refresh × hunk 外キャレット

    func testRefreshWithCaretOutsideHunksSelectsNearestAndKeepsRestoreRow() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMergeCrossLayer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let leftText = "a\nold1\nb\nold2\nc"
        let rightText = "a\nnew1\nb\nnew2\nc"
        let leftURL = directory.appendingPathComponent("left.txt")
        let rightURL = directory.appendingPathComponent("right.txt")
        try leftText.write(to: leftURL, atomically: true, encoding: .utf8)
        try rightText.write(to: rightURL, atomically: true, encoding: .utf8)

        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: leftText,
            rightText: rightText,
            leftPath: leftURL.path,
            rightPath: rightURL.path
        )
        XCTAssertNil(DiffLocationLayout.hunkIndex(containingRow: 0, in: viewModel.locationHunks))
        viewModel.setCaretContext(row: 0, side: .left)

        viewModel.refresh()

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.row, 0)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, true)
        XCTAssertEqual(viewModel.scrollToRow, 0)
        XCTAssertEqual(viewModel.lastKnownCaretRow, 0)
    }

    // MARK: - Edit × 選択 × キャレット

    func testCommitPaneEditPreservesHunkSelectionAndCaret() {
        let viewModel = FileCompareViewModel()
        viewModel.undoManager.groupsByEvent = false
        viewModel.seedComparison(
            leftText: "a\nold\nc",
            rightText: "a\nnew\nc"
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.clearPendingCaretLineStartRestore()
        viewModel.setCaretContext(row: 1, side: .left)

        let pane = DiffPaneTextLayout.contentPlainText(
            lines: viewModel.state.presentation,
            side: .left
        )
        let editedPane = pane.replacingOccurrences(of: "old", with: "older")
        viewModel.commitPaneEdit(side: .left, paneText: editedPane)

        XCTAssertEqual(viewModel.state.navigator.currentIndex, 0)
        XCTAssertEqual(viewModel.lastKnownCaretRow, 1)
        XCTAssertEqual(viewModel.state.leftText, "a\nolder\nc")
        XCTAssertTrue(viewModel.state.isLeftDirty)
    }
}
