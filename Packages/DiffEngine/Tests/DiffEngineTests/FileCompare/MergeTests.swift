import Foundation
import Testing
@testable import DiffEngine

@Test func mergeLeftToRightOnModifyReplacesRightLine() {
    let result = TextDiffer.compare("hello world", "hello swift")
    let merged = MergeOperations.apply(
        direction: .leftToRight,
        hunkIndex: 0,
        to: result
    )

    #expect(merged != nil)
    #expect(merged?.leftText == "hello world")
    #expect(merged?.rightText == "hello world")
}

@Test func mergeRightToLeftOnModifyReplacesLeftLine() {
    let result = TextDiffer.compare("hello world", "hello swift")
    let merged = MergeOperations.apply(
        direction: .rightToLeft,
        hunkIndex: 0,
        to: result
    )

    #expect(merged?.leftText == "hello swift")
    #expect(merged?.rightText == "hello swift")
}

@Test func mergeLeftToRightOnInsertRemovesExtraRightLine() {
    let result = TextDiffer.compare("a", "a\nb")
    let merged = MergeOperations.apply(
        direction: .leftToRight,
        hunkIndex: 0,
        to: result
    )

    #expect(merged?.leftText == "a")
    #expect(merged?.rightText == "a")
}

@Test func mergeRightToLeftOnInsertAddsLineToLeft() {
    let result = TextDiffer.compare("a", "a\nb")
    let merged = MergeOperations.apply(
        direction: .rightToLeft,
        hunkIndex: 0,
        to: result
    )

    #expect(merged?.leftText == "a\nb")
    #expect(merged?.rightText == "a\nb")
}

@Test func mergeLeftToRightOnDeleteAddsMissingLineToRight() {
    let result = TextDiffer.compare("a\nb", "a")
    let merged = MergeOperations.apply(
        direction: .leftToRight,
        hunkIndex: 0,
        to: result
    )

    #expect(merged?.leftText == "a\nb")
    #expect(merged?.rightText == "a\nb")
}

@Test func mergeRightToLeftOnDeleteRemovesExtraLeftLine() {
    let result = TextDiffer.compare("a\nb", "a")
    let merged = MergeOperations.apply(
        direction: .rightToLeft,
        hunkIndex: 0,
        to: result
    )

    #expect(merged?.leftText == "a")
    #expect(merged?.rightText == "a")
}

@Test func mergeAppliesOnlySelectedHunk() {
    let result = TextDiffer.compare(
        "a\nold1\nb\nold2\nc",
        "a\nnew1\nb\nnew2\nc"
    )
    #expect(result.hunks.count == 2)

    let merged = MergeOperations.apply(
        direction: .leftToRight,
        hunkIndex: 0,
        to: result
    )

    #expect(merged?.leftText == "a\nold1\nb\nold2\nc")
    #expect(merged?.rightText == "a\nold1\nb\nnew2\nc")
}

@Test func mergeRejectsInvalidHunkIndex() {
    let result = TextDiffer.compare("a", "b")
    #expect(MergeOperations.apply(direction: .leftToRight, hunkIndex: 1, to: result) == nil)
    #expect(MergeOperations.apply(direction: .leftToRight, hunkIndex: -1, to: result) == nil)
}

@Test func mergePreservesTrailingNewlinesWhenBothSidesEndWithNewline() {
    let result = TextDiffer.compare("hello\n", "world\n")
    #expect(result.leftEndsWithNewline == true)
    #expect(result.rightEndsWithNewline == true)

    let merged = MergeOperations.apply(direction: .leftToRight, hunkIndex: 0, to: result)
    #expect(merged?.leftText == "hello\n")
    #expect(merged?.rightText == "hello\n")
}

@Test func mergeLeftToRightTakesLeftTrailingNewlineForChangedRight() {
    let result = TextDiffer.compare("hello\n", "world")
    #expect(result.leftEndsWithNewline == true)
    #expect(result.rightEndsWithNewline == false)

    let merged = MergeOperations.apply(direction: .leftToRight, hunkIndex: 0, to: result)
    #expect(merged?.leftText == "hello\n")
    #expect(merged?.rightText == "hello\n")
}

@Test func mergeRightToLeftTakesRightTrailingNewlineForChangedLeft() {
    let result = TextDiffer.compare("hello\n", "world")
    #expect(result.leftEndsWithNewline == true)
    #expect(result.rightEndsWithNewline == false)

    let merged = MergeOperations.apply(direction: .rightToLeft, hunkIndex: 0, to: result)
    #expect(merged?.leftText == "world")
    #expect(merged?.rightText == "world")
}

@Test func mergePreservesUnchangedSideTrailingNewlineOnPartialHunkCopy() {
    let result = TextDiffer.compare(
        "a\nold1\nb\nold2\nc\n",
        "a\nnew1\nb\nnew2\nc\n"
    )
    #expect(result.hunks.count == 2)
    #expect(result.leftEndsWithNewline == true)
    #expect(result.rightEndsWithNewline == true)

    let merged = MergeOperations.apply(direction: .leftToRight, hunkIndex: 0, to: result)
    #expect(merged?.leftText == "a\nold1\nb\nold2\nc\n")
    #expect(merged?.rightText == "a\nold1\nb\nnew2\nc\n")
}

@Test func mergeCaretRemapCountsSourceContentRowsForLeftToRight() {
    let result = TextDiffer.compare("a\nold\nc", "a\nnew1\nnew2\nc")
    #expect(result.hunks.count == 1)
    let hunk = result.hunks[0]
    let remap = MergeOperations.caretRemap(direction: .leftToRight, hunkIndex: 0, to: result)
    #expect(remap?.replacedStart == hunk.startRow)
    #expect(remap?.replacedOldCount == hunk.rowCount)
    // Source (left) has one content line in the hunk.
    #expect(remap?.replacedNewCount == 1)
}

@Test func fileCompareStateCopyReturnsCaretRemap() {
    var state = FileCompareState()
    state.setLeftText("a\nold\nc")
    state.setRightText("a\nnew1\nnew2\nc")
    let hunk = state.result!.hunks[0]
    #expect(state.selectHunk(0) == 0)
    let remap = state.copyCurrentHunk(to: .right)
    #expect(remap?.replacedStart == hunk.startRow)
    #expect(remap?.replacedOldCount == hunk.rowCount)
    #expect(remap?.replacedNewCount == 1)
}

@Test func fileCompareStateCopyLeftToRightMarksRightDirty() {
    var state = FileCompareState()
    state.setLeftText("alpha")
    state.setRightText("beta")

    #expect(state.isLeftDirty == false)
    #expect(state.isRightDirty == false)
    #expect(state.selectHunk(0) == 0)
    #expect(state.copyCurrentHunk(to: .right) != nil)
    #expect(state.leftText == "alpha")
    #expect(state.rightText == "alpha")
    #expect(state.isLeftDirty == false)
    #expect(state.isRightDirty == true)
    #expect(state.hasChanges == false)
}

@Test func fileCompareStateCopyRightToLeftMarksLeftDirty() {
    var state = FileCompareState()
    state.setLeftText("alpha")
    state.setRightText("beta")

    #expect(state.selectHunk(0) == 0)
    #expect(state.copyCurrentHunk(to: .left) != nil)
    #expect(state.leftText == "beta")
    #expect(state.rightText == "beta")
    #expect(state.isLeftDirty == true)
    #expect(state.isRightDirty == false)
}

@Test func fileCompareStateMarkSavedClearsDirtyFlag() {
    var state = FileCompareState()
    state.setLeftText("a")
    state.setRightText("b")
    #expect(state.selectHunk(0) == 0)
    #expect(state.copyCurrentHunk(to: .right) != nil)
    #expect(state.isRightDirty == true)

    state.markRightSaved()
    #expect(state.isRightDirty == false)
    #expect(state.isLeftDirty == false)
}

@Test func fileCompareStateReloadClearsDirty() {
    var state = FileCompareState()
    state.setLeftText("a")
    state.setRightText("b")
    #expect(state.selectHunk(0) == 0)
    _ = state.copyCurrentHunk(to: .left)
    #expect(state.isLeftDirty == true)

    state.setLeftText("fresh")
    #expect(state.isLeftDirty == false)
}

@Test func fileCompareStateCopyWithoutHunkReturnsFalse() {
    var state = FileCompareState()
    state.setLeftText("same")
    state.setRightText("same")
    #expect(state.copyCurrentHunk(to: .right) == nil)
}

@Test func fileCompareStateCopyClearsSelectionWhenHunkResolved() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.navigator.hunkCount == 2)
    #expect(state.selectHunk(0) == 0)
    #expect(state.copyCurrentHunk(to: .right) != nil)
    #expect(state.navigator.hunkCount == 1)
    #expect(state.navigator.currentIndex == nil)
    #expect(state.rightText == "a\nold1\nb\nnew2\nc")
}

@Test func fileCompareStateGoNextAfterCopyUsesCaretWhenUnselected() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.selectHunk(0) == 0)
    #expect(state.copyCurrentHunk(to: .right) != nil)
    #expect(state.navigator.currentIndex == nil)
    #expect(state.navigator.hunkCount == 1)
    #expect(state.goNextHunk(caretRow: 1) == 3)
    #expect(state.navigator.currentIndex == 0)
}

@Test func fileCompareStateCopyAndAdvanceSelectsRemainingHunk() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.navigator.hunkCount == 2)
    #expect(state.selectHunk(0) == 0)
    #expect(state.copyCurrentHunkAndAdvance(to: .right) != nil)
    #expect(state.navigator.hunkCount == 1)
    #expect(state.navigator.currentIndex == 0)
    #expect(state.rightText == "a\nold1\nb\nnew2\nc")
}

@Test func fileCompareStateCopyAndAdvanceOnLastHunkClearsSelection() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.selectHunk(1) == 1)
    #expect(state.copyCurrentHunkAndAdvance(to: .right) != nil)
    #expect(state.navigator.hunkCount == 1)
    #expect(state.navigator.currentIndex == nil)
    #expect(state.rightText == "a\nnew1\nb\nold2\nc")
}

@Test func fileCompareStateCopySecondHunkClearsSelectionWithoutAdvancing() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.selectHunk(1) == 1)
    #expect(state.copyCurrentHunk(to: .right) != nil)
    #expect(state.navigator.hunkCount == 1)
    #expect(state.navigator.currentIndex == nil)
    #expect(state.rightText == "a\nnew1\nb\nold2\nc")
}

@Test func fileCompareStateRestoreEditSnapshotRevertsCopy() {
    var state = FileCompareState()
    state.setLeftText("alpha")
    state.setRightText("beta")
    #expect(state.navigator.currentIndex == nil)

    let snapshot = state.makeEditSnapshot()
    #expect(snapshot.leftText == "alpha")
    #expect(snapshot.rightText == "beta")
    #expect(snapshot.isLeftDirty == false)
    #expect(snapshot.isRightDirty == false)
    #expect(snapshot.selectedHunkIndex == nil)

    #expect(state.selectHunk(0) == 0)
    #expect(state.copyCurrentHunk(to: .right) != nil)
    #expect(state.rightText == "alpha")
    #expect(state.isRightDirty == true)
    #expect(state.navigator.currentIndex == nil)

    state.restoreEditSnapshot(snapshot)
    #expect(state.leftText == "alpha")
    #expect(state.rightText == "beta")
    #expect(state.isLeftDirty == false)
    #expect(state.isRightDirty == false)
    #expect(state.navigator.currentIndex == nil)
    #expect(state.hasChanges == true)
}

@Test func fileCompareStateRestoreEditSnapshotAfterCopyAndAdvance() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.navigator.hunkCount == 2)
    #expect(state.navigator.currentIndex == nil)

    let snapshot = state.makeEditSnapshot()
    #expect(state.selectHunk(0) == 0)
    #expect(state.copyCurrentHunkAndAdvance(to: .right) != nil)
    #expect(state.rightText == "a\nold1\nb\nnew2\nc")
    #expect(state.navigator.hunkCount == 1)
    #expect(state.navigator.currentIndex == 0)
    #expect(state.isRightDirty == true)

    state.restoreEditSnapshot(snapshot)
    #expect(state.leftText == "a\nold1\nb\nold2\nc")
    #expect(state.rightText == "a\nnew1\nb\nnew2\nc")
    #expect(state.isRightDirty == false)
    #expect(state.navigator.hunkCount == 2)
    #expect(state.navigator.currentIndex == nil)
}

@Test func fileContentWriterRoundTripsUTF8() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HomMergeMergeTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let url = directory.appendingPathComponent("sample.txt")
    let text = "save test\nline2"
    try FileContentWriter.write(text, to: url)
    #expect(try FileContentLoader.load(from: url) == text)
}
