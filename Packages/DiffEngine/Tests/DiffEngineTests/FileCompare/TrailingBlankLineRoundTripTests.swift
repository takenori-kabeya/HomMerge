import Foundation
import Testing
@testable import DiffEngine

@Test func lineSplitterKeepsTrailingEmptyForUnixNewline() {
    let helloNL = LineSplitter.splitDetailed("hello\n")
    #expect(helloNL.lines == ["hello", ""])
    #expect(helloNL.endsWithNewline == true)

    let twoBlanks = LineSplitter.splitDetailed("hello\n\n\n")
    #expect(twoBlanks.lines == ["hello", "", "", ""])
    #expect(twoBlanks.endsWithNewline == true)

    let onlyNL = LineSplitter.splitDetailed("\n")
    #expect(onlyNL.lines == ["", ""])
    #expect(onlyNL.endsWithNewline == true)
}

@Test func enterOnceAtEOFAddsOneContentBlankLine() {
    var state = FileCompareState()
    state.setLeftText("hello\n")
    state.setRightText("hello\n")

    let pane = DiffPaneTextLayout.contentPlainText(lines: state.presentation, side: .left)
    #expect(pane == "hello\n")

    let afterEnter = pane + "\n"
    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: afterEnter,
        lines: state.presentation,
        side: .left
    )
    #expect(fileText == "hello\n\n")
    #expect(LineSplitter.splitDetailed(fileText).lines == ["hello", "", ""])
}

@Test func deletingOneTrailingBlankRemovesExactlyOne() {
    var state = FileCompareState()
    state.setLeftText("hello\n\n\n")
    state.setRightText("hello\n\n\n")

    let pane = DiffPaneTextLayout.contentPlainText(lines: state.presentation, side: .left)
    #expect(pane == "hello\n\n\n")

    // Drop one trailing blank from the pane (one fewer `\n`).
    let afterDelete = "hello\n\n"
    let fileText = DiffPaneTextLayout.fileTextByDroppingGapRows(
        paneText: afterDelete,
        lines: state.presentation,
        side: .left
    )
    #expect(fileText == "hello\n\n")
    #expect(LineSplitter.splitDetailed(fileText).lines == ["hello", "", ""])
}

@Test func lastEmptyPresentationRowCaretLocationIsAtStringEnd() {
    let result = TextDiffer.compare("hello\n", "hello\n")
    let lines = SideBySideBuilder.build(from: result)
    #expect(lines.count == 2)
    #expect(DiffPaneTextLayout.text(for: lines[1], side: .left) == "")

    let pane = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
    let lastRowStart = DiffPaneTextLayout.utf16Location(forRow: 1, in: lines, side: .left)
    #expect(lastRowStart == (pane as NSString).length)
    #expect(DiffPaneTextLayout.row(forUtf16Location: lastRowStart, in: lines, side: .left) == 1)
}

@Test func mergeEOFOnlyHunkBothDirectionsMakesSidesIdenticalWithoutDoubleNewline() {
    let leftHasEOF = TextDiffer.compare("hello\n", "hello")
    #expect(leftHasEOF.hunks.count == 1)

    let copyEOF = MergeOperations.apply(direction: .leftToRight, hunkIndex: 0, to: leftHasEOF)
    #expect(copyEOF?.leftText == "hello\n")
    #expect(copyEOF?.rightText == "hello\n")
    #expect(copyEOF?.leftText.contains("\n\n") == false)

    let clearEOF = MergeOperations.apply(direction: .rightToLeft, hunkIndex: 0, to: leftHasEOF)
    #expect(clearEOF?.leftText == "hello")
    #expect(clearEOF?.rightText == "hello")
}
