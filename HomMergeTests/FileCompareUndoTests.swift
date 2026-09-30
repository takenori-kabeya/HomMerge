import AppKit
import XCTest
@testable import HomMerge

@MainActor
final class FileCompareUndoTests: XCTestCase {
    func testCopyHunkToRightCanUndoAndRedoViaUndoManager() {
        let viewModel = FileCompareViewModel()
        viewModel.undoManager.groupsByEvent = false
        viewModel.seedComparison(leftText: "alpha", rightText: "beta")

        XCTAssertEqual(viewModel.state.leftText, "alpha")
        XCTAssertEqual(viewModel.state.rightText, "beta")
        XCTAssertFalse(viewModel.state.isRightDirty)
        XCTAssertFalse(viewModel.undoManager.canUndo)

        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRight()
        XCTAssertEqual(viewModel.state.rightText, "alpha")
        XCTAssertTrue(viewModel.state.isRightDirty)
        XCTAssertTrue(viewModel.undoManager.canUndo)

        viewModel.undoManager.undo()
        XCTAssertEqual(viewModel.state.leftText, "alpha")
        XCTAssertEqual(viewModel.state.rightText, "beta")
        XCTAssertFalse(viewModel.state.isRightDirty)
        XCTAssertTrue(viewModel.undoManager.canRedo)

        viewModel.undoManager.redo()
        XCTAssertEqual(viewModel.state.rightText, "alpha")
        XCTAssertTrue(viewModel.state.isRightDirty)
        XCTAssertTrue(viewModel.undoManager.canUndo)
    }

    func testRefreshClearsMergeUndoHistory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMergeUndoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let leftURL = directory.appendingPathComponent("left.txt")
        let rightURL = directory.appendingPathComponent("right.txt")
        try "alpha".write(to: leftURL, atomically: true, encoding: .utf8)
        try "beta".write(to: rightURL, atomically: true, encoding: .utf8)

        let viewModel = FileCompareViewModel()
        viewModel.undoManager.groupsByEvent = false
        viewModel.seedComparison(
            leftText: "alpha",
            rightText: "beta",
            leftPath: leftURL.path,
            rightPath: rightURL.path
        )
        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRight()
        XCTAssertTrue(viewModel.undoManager.canUndo)
        viewModel.saveRight()
        XCTAssertFalse(viewModel.state.isRightDirty)
        XCTAssertTrue(viewModel.undoManager.canUndo)

        viewModel.refresh()
        XCTAssertFalse(viewModel.undoManager.canUndo)
        XCTAssertEqual(viewModel.state.leftText, "alpha")
        XCTAssertEqual(viewModel.state.rightText, "alpha")
        XCTAssertFalse(viewModel.state.isRightDirty)
    }

    func testCopyHunkToRightEnablesMergeUndoWithoutPaneFocus() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(leftText: "alpha", rightText: "beta")
        XCTAssertFalse(viewModel.canMergeUndo)

        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRight()

        XCTAssertTrue(viewModel.canMergeUndo)
        XCTAssertGreaterThan(viewModel.mergeUndoRevision, 0)
    }

    func testNextDifferenceEnabledBeforeCaretFocus() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(leftText: "alpha", rightText: "beta")
        XCTAssertNil(viewModel.lastKnownCaretRow)
        XCTAssertNil(viewModel.currentHunkIndex)
        XCTAssertTrue(viewModel.canGoNextDifference)

        viewModel.goNextDifference()
        XCTAssertEqual(viewModel.currentHunkIndex, 0)
    }

    func testUndoIncrementsPaneApplyToken() {
        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(leftText: "alpha", rightText: "beta")
        let tokenBeforeCopy = viewModel.paneApplyToken

        viewModel.selectHunkAndScroll(0)
        viewModel.copyHunkToRight()
        XCTAssertGreaterThan(viewModel.paneApplyToken, tokenBeforeCopy)

        let tokenAfterCopy = viewModel.paneApplyToken
        viewModel.undoManager.undo()
        XCTAssertGreaterThan(viewModel.paneApplyToken, tokenAfterCopy)
        XCTAssertEqual(viewModel.state.rightText, "beta")
        XCTAssertFalse(viewModel.state.isRightDirty)
    }

    func testDiffPaneContentTextViewForwardsUndoToMergeUndoManager() {
        let host = DiffPaneHostView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let mergeUndoManager = UndoManager()
        let undoTarget = NSObject()
        var undoCount = 0
        mergeUndoManager.registerUndo(withTarget: undoTarget) { _ in
            undoCount += 1
        }
        host.mergeUndoManager = mergeUndoManager

        guard let textView = host.leftScrollView.documentView as? DiffPaneContentTextView else {
            XCTFail("Expected DiffPaneContentTextView")
            return
        }

        XCTAssertFalse(textView.allowsUndo)
        XCTAssertTrue(mergeUndoManager.canUndo)

        let undoItem = NSMenuItem(
            title: "Undo",
            action: #selector(DiffPaneContentTextView.undo(_:)),
            keyEquivalent: "z"
        )
        XCTAssertTrue(textView.validateUserInterfaceItem(undoItem))

        textView.undo(nil)
        XCTAssertEqual(undoCount, 1)
    }

    func testDiffPaneContentTextViewForwardsRedoToMergeUndoManager() {
        let host = DiffPaneHostView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let mergeUndoManager = UndoManager()
        let undoTarget = NSObject()
        var redoInvoked = false
        mergeUndoManager.registerUndo(withTarget: undoTarget) { _ in
            mergeUndoManager.registerUndo(withTarget: undoTarget) { _ in
                redoInvoked = true
            }
        }
        mergeUndoManager.undo()
        host.mergeUndoManager = mergeUndoManager

        guard let textView = host.leftScrollView.documentView as? DiffPaneContentTextView else {
            XCTFail("Expected DiffPaneContentTextView")
            return
        }

        XCTAssertTrue(mergeUndoManager.canRedo)

        let redoItem = NSMenuItem(
            title: "Redo",
            action: #selector(DiffPaneContentTextView.redo(_:)),
            keyEquivalent: "Z"
        )
        XCTAssertTrue(textView.validateUserInterfaceItem(redoItem))

        textView.redo(nil)
        XCTAssertTrue(redoInvoked)
    }
}
