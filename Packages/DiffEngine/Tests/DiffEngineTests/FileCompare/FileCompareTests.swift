import Foundation
import Testing
@testable import DiffEngine

@Test func lineSplitterIsUsedByPresentation() {
    let result = TextDiffer.compare("a\nb", "a\nc")
    let lines = SideBySideBuilder.build(from: result)

    #expect(lines.count == 2)
    #expect(lines[0].kind == .equal)
    #expect(lines[0].leftText == "a")
    #expect(lines[0].rightText == "a")
    #expect(lines[0].leftLineNumber == 1)
    #expect(lines[0].rightLineNumber == 1)
    #expect(lines[1].kind == .modify)
    #expect(lines[1].leftText == "b")
    #expect(lines[1].rightText == "c")
}

@Test func insertRowLeavesLeftTextEmptyWithNilLineNumber() {
    let result = TextDiffer.compare("a", "a\nb")
    let lines = SideBySideBuilder.build(from: result)

    #expect(lines.map(\.kind) == [.equal, .insert])
    #expect(lines[1].leftText == "")
    #expect(lines[1].leftLineNumber == nil)
    #expect(lines[1].rightText == "b")
    #expect(lines[1].rightLineNumber == 2)
}

@Test func deleteRowLeavesRightTextEmptyWithNilLineNumber() {
    let result = TextDiffer.compare("a\nb", "a")
    let lines = SideBySideBuilder.build(from: result)

    #expect(lines.map(\.kind) == [.equal, .delete])
    #expect(lines[1].leftText == "b")
    #expect(lines[1].leftLineNumber == 2)
    #expect(lines[1].rightText == "")
    #expect(lines[1].rightLineNumber == nil)
}

@Test func presentationPreservesInlineSpansOnModify() {
    let result = TextDiffer.compare("hello world", "hello swift")
    let lines = SideBySideBuilder.build(from: result)

    #expect(lines.count == 1)
    #expect(lines[0].leftInlineSpans == result.alignedRows[0].leftInlineSpans)
    #expect(lines[0].rightInlineSpans == result.alignedRows[0].rightInlineSpans)
}

@Test func hunkNavigatorStartsWithNoSelectionWhenPresent() {
    let navigator = HunkNavigator(hunkCount: 3)

    #expect(navigator.currentIndex == nil)
    #expect(navigator.hunkCount == 3)
}

@Test func hunkNavigatorIsNilWhenNoHunks() {
    var navigator = HunkNavigator(hunkCount: 0)

    #expect(navigator.currentIndex == nil)
    #expect(navigator.goNext() == nil)
    #expect(navigator.goPrevious() == nil)
}

@Test func hunkNavigatorAdvancesAndStopsAtEnds() {
    var navigator = HunkNavigator(hunkCount: 3)

    #expect(navigator.goNext() == 0)
    #expect(navigator.goNext() == 1)
    #expect(navigator.goNext() == 2)
    #expect(navigator.goNext() == nil)
    #expect(navigator.currentIndex == 2)

    #expect(navigator.goPrevious() == 1)
    #expect(navigator.goPrevious() == 0)
    #expect(navigator.goPrevious() == nil)
    #expect(navigator.currentIndex == 0)
}

@Test func hunkNavigatorGoNextFromClearedSelectionSelectsFirst() {
    var navigator = HunkNavigator(hunkCount: 3)
    navigator.clearSelection()
    #expect(navigator.currentIndex == nil)
    #expect(navigator.goNext() == 0)
    #expect(navigator.currentIndex == 0)
}

@Test func hunkNavigatorGoPreviousFromClearedSelectionSelectsLast() {
    var navigator = HunkNavigator(hunkCount: 3)
    navigator.clearSelection()
    #expect(navigator.goPrevious() == 2)
    #expect(navigator.currentIndex == 2)
}

@Test func hunkNavigatorSelectHunkClampsToValidRange() {
    var navigator = HunkNavigator(hunkCount: 2)

    #expect(navigator.selectHunk(1) == 1)
    #expect(navigator.selectHunk(99) == nil)
    #expect(navigator.currentIndex == 1)
    #expect(navigator.selectHunk(-1) == nil)
    #expect(navigator.currentIndex == 1)
}

@Test func hunkNavigatorGoFirstAndLastMoveToEnds() {
    var navigator = HunkNavigator(hunkCount: 3)
    _ = navigator.goNext()
    #expect(navigator.currentIndex == 0)

    #expect(navigator.goFirst() == 0)
    #expect(navigator.currentIndex == 0)
    #expect(navigator.goFirst() == 0)

    #expect(navigator.goLast() == 2)
    #expect(navigator.currentIndex == 2)
    #expect(navigator.goLast() == 2)
}

@Test func hunkNavigatorGoCurrentKeepsSelectionOrSelectsFirstWhenCleared() {
    var navigator = HunkNavigator(hunkCount: 3)
    _ = navigator.goNext()
    #expect(navigator.goCurrent() == 0)
    #expect(navigator.currentIndex == 0)

    navigator.clearSelection()
    #expect(navigator.goCurrent() == 0)
    #expect(navigator.currentIndex == 0)
}

@Test func hunkNavigatorGoFirstLastCurrentReturnNilWhenEmpty() {
    var navigator = HunkNavigator(hunkCount: 0)

    #expect(navigator.goFirst() == nil)
    #expect(navigator.goLast() == nil)
    #expect(navigator.goCurrent() == nil)
}

@Test func utf8TextLoadsSuccessfully() throws {
    let text = "hello\nworld"
    let data = Data(text.utf8)
    let loaded = try FileContentLoader.load(data: data)
    #expect(loaded == text)
}

@Test func nullByteDataIsRejectedAsBinary() {
    let data = Data([0x48, 0x69, 0x00, 0x21])
    #expect(FileContentLoader.isBinary(data) == true)
    #expect(throws: FileLoadError.binary) {
        try FileContentLoader.load(data: data)
    }
}

@Test func invalidUTF8IsRejected() {
    let data = Data([0xFF, 0xFE, 0xFD])
    #expect(FileContentLoader.isBinary(data) == false)
    #expect(throws: FileLoadError.notUTF8) {
        try FileContentLoader.load(data: data)
    }
}

@Test func emptyDataLoadsAsEmptyString() throws {
    #expect(try FileContentLoader.load(data: Data()) == "")
    #expect(FileContentLoader.isBinary(Data()) == false)
}

@Test func fileCompareStateRecomputesDiffWhenBothSidesSet() {
    var state = FileCompareState()
    state.setLeftText("a\nb")
    #expect(state.result == nil)

    state.setRightText("a\nc")
    #expect(state.result != nil)
    #expect(state.presentation.map(\.kind) == [.equal, .modify])
    #expect(state.navigator.hunkCount == 1)
    #expect(state.navigator.currentIndex == nil)
    #expect(state.canCompare == true)
}

@Test func fileCompareStateSurfacesBinaryErrorWithoutDiff() {
    var state = FileCompareState()
    state.setRightText("ok")
    state.setLeftFailure(.binary)

    #expect(state.leftError == .binary)
    #expect(state.canCompare == false)
    #expect(state.result == nil)
    #expect(state.presentation.isEmpty)
}

@Test func fileCompareStateNextPreviousHunkUseNavigator() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")

    #expect(state.navigator.hunkCount == 2)
    #expect(state.currentHunkStartRow == nil)
    #expect(state.goNextHunk() == 1)
    #expect(state.navigator.currentIndex == 0)
    #expect(state.goNextHunk() == 3)
    #expect(state.goNextHunk() == nil)
    #expect(state.goPreviousHunk() == 1)
}

@Test func fileCompareStateGoNextHunkUsesCaretWhenUnselected() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")

    #expect(state.navigator.currentIndex == nil)
        #expect(state.goNextHunk(caretRow: 1) == 3)
    #expect(state.navigator.currentIndex == 1)
    state.clearHunkSelection()
    #expect(state.goPreviousHunk(caretRow: 3) == 1)
    #expect(state.navigator.currentIndex == 0)
}

@Test func fileCompareStateFirstLastCurrentHunkUseNavigator() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")

    #expect(state.navigator.hunkCount == 2)
    #expect(state.goLastHunk() == 3)
    #expect(state.navigator.currentIndex == 1)
    #expect(state.goFirstHunk() == 1)
    #expect(state.navigator.currentIndex == 0)
    #expect(state.goCurrentHunk(caretRow: 1) == 1)
    #expect(state.navigator.currentIndex == 0)
    #expect(state.goCurrentHunk(caretRow: 0) == nil)

    state.setLeftText("same")
    state.setRightText("same")
    #expect(state.navigator.hunkCount == 0)
    #expect(state.goFirstHunk() == nil)
    #expect(state.goLastHunk() == nil)
    #expect(state.goCurrentHunk(caretRow: 0) == nil)
}

@Test func fileCompareStateGoNearestHunkSelectsCaretNearestEvenWhenAnotherHunkSelected() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.selectHunk(1) == 1)
    #expect(state.goNearestHunk(caretRow: 1) == 1)
    #expect(state.navigator.currentIndex == 0)
}

@Test func fileCompareStateGoNearestHunkKeepsSelectionWhenCaretAlreadyNearest() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.selectHunk(1) == 1)
    #expect(state.goNearestHunk(caretRow: 3) == 3)
    #expect(state.navigator.currentIndex == 1)
}

@Test func fileCompareStateGoNearestHunkUsesCaretWhenUnselected() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.goNearestHunk(caretRow: 3) == 3)
    #expect(state.navigator.currentIndex == 1)
}

@Test func fileCompareStateCanGoNearestHunkRequiresCaretRegardlessOfSelection() {
    var state = FileCompareState()
    state.setLeftText("a\nold1\nb\nold2\nc")
    state.setRightText("a\nnew1\nb\nnew2\nc")
    #expect(state.selectHunk(0) == 0)
    #expect(state.canGoNearestHunk(caretRow: nil) == false)
    #expect(state.canGoNearestHunk(caretRow: 1) == true)

    state.setLeftText("same")
    state.setRightText("same")
    #expect(state.canGoNearestHunk(caretRow: 0) == false)
}

@Test func fileCompareStateClearsErrorWhenTextReplaced() {
    var state = FileCompareState()
    state.setLeftFailure(.notUTF8)
    state.setLeftText("recovered")
    state.setRightText("recovered")

    #expect(state.leftError == nil)
    #expect(state.hasChanges == false)
}
