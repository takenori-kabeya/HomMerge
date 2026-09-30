import Foundation
import Testing
@testable import DiffEngine

@Test func clipboardTextByDroppingGapRowsOmitsEmptyGapInFullSelection() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")
    let lines = SideBySideBuilder.build(from: result)
    let pane = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
    let fullRange = NSRange(location: 0, length: (pane as NSString).length)

    let clipboard = DiffPaneTextLayout.clipboardTextByDroppingGapRows(
        paneText: pane,
        selectedRange: fullRange,
        lines: lines,
        side: .left
    )
    #expect(clipboard == "a\nc")
}

@Test func clipboardTextByDroppingGapRowsReturnsEmptyForGapOnlySelection() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")
    let lines = SideBySideBuilder.build(from: result)
    let pane = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
    // Middle row is the empty left gap opposite right's "b".
    let gapStart = DiffPaneTextLayout.utf16Location(forRow: 1, in: lines, side: .left)
    let gapRange = NSRange(location: gapStart, length: 0)

    let clipboard = DiffPaneTextLayout.clipboardTextByDroppingGapRows(
        paneText: pane,
        selectedRange: gapRange,
        lines: lines,
        side: .left
    )
    #expect(clipboard == "")
}

@Test func clipboardTextByDroppingGapRowsKeepsRealBlankLines() {
    let result = TextDiffer.compare("a\n\nc", "a\n\nc")
    let lines = SideBySideBuilder.build(from: result)
    let pane = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
    let fullRange = NSRange(location: 0, length: (pane as NSString).length)

    let clipboard = DiffPaneTextLayout.clipboardTextByDroppingGapRows(
        paneText: pane,
        selectedRange: fullRange,
        lines: lines,
        side: .left
    )
    #expect(clipboard == "a\n\nc")
}

@Test func clipboardTextByDroppingGapRowsKeepsNonEmptyGapContent() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")
    let lines = SideBySideBuilder.build(from: result)
    var paneRows = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    paneRows[1] = "b"
    let pane = paneRows.joined(separator: "\n")
    let fullRange = NSRange(location: 0, length: (pane as NSString).length)

    let clipboard = DiffPaneTextLayout.clipboardTextByDroppingGapRows(
        paneText: pane,
        selectedRange: fullRange,
        lines: lines,
        side: .left
    )
    #expect(clipboard == "a\nb\nc")
}

@Test func clipboardTextByDroppingGapRowsKeepsPartialLineSelection() {
    let result = TextDiffer.compare("hello", "hello")
    let lines = SideBySideBuilder.build(from: result)
    let pane = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
    let partialRange = NSRange(location: 1, length: 3)

    let clipboard = DiffPaneTextLayout.clipboardTextByDroppingGapRows(
        paneText: pane,
        selectedRange: partialRange,
        lines: lines,
        side: .left
    )
    #expect(clipboard == "ell")
}

@Test func fileTextByDroppingGapRowsRemovesInsertGapsOnLeft() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")
    let lines = SideBySideBuilder.build(from: result)
    // Left pane has an empty gap row where right inserts "b".
    let pane = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
    #expect(pane.split(separator: "\n", omittingEmptySubsequences: false).count == 3)

    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: lines,
        side: .left
    )
    #expect(fileText == "a\nc")
}

@Test func fileTextByDroppingGapRowsKeepsAllRowsWhenNoGaps() {
    let result = TextDiffer.compare("a\nb", "a\nb")
    let lines = SideBySideBuilder.build(from: result)
    let pane = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)

    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: lines,
        side: .left
    )
    #expect(fileText == "a\nb")
}

@Test func fileTextByDroppingGapRowsKeepsUserEditsOnRealRows() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")
    let lines = SideBySideBuilder.build(from: result)
    // Simulate editing the last real left line while leaving the gap blank.
    var paneRows = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    #expect(paneRows.count == 3)
    paneRows[2] = "c-edited"
    let pane = paneRows.joined(separator: "\n")

    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: lines,
        side: .left
    )
    #expect(fileText == "a\nc-edited")
}

@Test func fileTextByDroppingGapRowsKeepsNonEmptyGapAsFileLine() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")
    let lines = SideBySideBuilder.build(from: result)
    var paneRows = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    #expect(paneRows.count == 3)
    // Middle row is the left gap opposite right's inserted "b".
    #expect(paneRows[1].isEmpty)
    paneRows[1] = "b"
    let pane = paneRows.joined(separator: "\n")

    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: lines,
        side: .left
    )
    #expect(fileText == "a\nb\nc")
}

@Test func fileTextByDroppingGapRowsAbsorbsSpacersPushedOutByMultiLinePaste() {
    let result = TextDiffer.compare("a\nc", "a\nb1\nb2\nc")
    let lines = SideBySideBuilder.build(from: result)
    var paneRows = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    #expect(paneRows.count == 4)
    #expect(paneRows[1].isEmpty)
    #expect(paneRows[2].isEmpty)
    // Paste "x\ny" over the first gap row: the second spacer is pushed down.
    paneRows.replaceSubrange(1...1, with: ["x", "y"])
    let pane = paneRows.joined(separator: "\n")

    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: lines,
        side: .left
    )
    #expect(fileText == "a\nx\ny\nc")
}

@Test func fileTextByDroppingGapRowsDropsRemainingGapsAfterSingleLinePaste() {
    let result = TextDiffer.compare("a\nc", "a\nb1\nb2\nc")
    let lines = SideBySideBuilder.build(from: result)
    var paneRows = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    paneRows[1] = "x"
    let pane = paneRows.joined(separator: "\n")

    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: lines,
        side: .left
    )
    #expect(fileText == "a\nx\nc")
}

@Test func fileTextByDroppingGapRowsKeepsAllPastedLinesInSingleGap() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")
    let lines = SideBySideBuilder.build(from: result)
    var paneRows = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    paneRows.replaceSubrange(1...1, with: ["x", "y", "z"])
    let pane = paneRows.joined(separator: "\n")

    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: lines,
        side: .left
    )
    #expect(fileText == "a\nx\ny\nz\nc")
}

@Test func fileTextByDroppingGapRowsKeepsRealBlankLines() {
    let result = TextDiffer.compare("a\n\nc", "a\n\nc")
    let lines = SideBySideBuilder.build(from: result)
    let pane = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)

    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: lines,
        side: .left
    )
    #expect(fileText == "a\n\nc")
}

@Test func applyEditedTextFromFilledGapMarksDirty() {
    var state = FileCompareState()
    state.setLeftText("a\nc")
    state.setRightText("a\nb\nc")

    var paneRows = DiffPaneTextLayout.contentPlainText(lines: state.presentation, side: .left)
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
    paneRows[1] = "b"
    let pane = paneRows.joined(separator: "\n")
    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: state.presentation,
        side: .left
    )
    #expect(fileText == "a\nb\nc")

    state.applyEditedText(fileText, side: .left)

    #expect(state.isLeftDirty == true)
    #expect(state.leftText == "a\nb\nc")
    #expect(state.hasChanges == false)
}

@Test func applyEditedTextMarksDirtyAndRecomputes() {
    var state = FileCompareState()
    state.setLeftText("hello\nworld")
    state.setRightText("hello\nworld")
    #expect(state.isLeftDirty == false)
    #expect(state.hasChanges == false)

    state.applyEditedText("hello\nswift", side: .left)

    #expect(state.isLeftDirty == true)
    #expect(state.isRightDirty == false)
    #expect(state.leftText == "hello\nswift")
    #expect(state.hasChanges == true)
    #expect(state.navigator.currentIndex == nil)
}

@Test func applyEditedTextOnRightMarksRightDirty() {
    var state = FileCompareState()
    state.setLeftText("same")
    state.setRightText("same")

    state.applyEditedText("changed", side: .right)

    #expect(state.isRightDirty == true)
    #expect(state.isLeftDirty == false)
    #expect(state.rightText == "changed")
}

@Test func applyEditedTextPreservesCurrentHunkSelection() {
    var state = FileCompareState()
    state.setLeftText("a\nold\nc")
    state.setRightText("a\nnew\nc")
    #expect(state.navigator.hunkCount == 1)
    #expect(state.selectHunk(0) == 0)

    state.applyEditedText("a\nolder\nc", side: .left)

    #expect(state.navigator.currentIndex == 0)
    #expect(state.hasChanges == true)
}

@Test func normalizingTrailingNewlineKeepsPreviousTrailingNewline() {
    let edited = DiffPaneTextLayout.normalizingTrailingNewline(
        edited: "a\nb",
        previous: "a\nb\n"
    )
    #expect(edited == "a\nb\n")
}

@Test func normalizingTrailingNewlineDoesNotAddNewlineWhenPreviousHadNone() {
    let edited = DiffPaneTextLayout.normalizingTrailingNewline(
        edited: "a\nb",
        previous: "a\nb"
    )
    #expect(edited == "a\nb")
}

@Test func normalizingTrailingNewlineKeepsEditedTrailingNewline() {
    let edited = DiffPaneTextLayout.normalizingTrailingNewline(
        edited: "a\nb\n",
        previous: "a\nb"
    )
    #expect(edited == "a\nb\n")
}

@Test func commitRoundTripWithTrailingNewlineMatchesOriginal() {
    var state = FileCompareState()
    state.setLeftText("a\nb\n")
    state.setRightText("a\nb\n")
    #expect(state.selectHunk(0) == nil)

    let pane = DiffPaneTextLayout.contentPlainText(lines: state.presentation, side: .left)
    let stripped = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: pane,
        lines: state.presentation,
        side: .left
    )
    let normalized = DiffPaneTextLayout.normalizingTrailingNewline(
        edited: stripped,
        previous: state.leftText
    )
    #expect(normalized == state.leftText)
}
