import Foundation
import Testing
@testable import DiffEngine

@Test func diffPaneTextLayoutGutterDigitCountUsesMinimumFour() {
    #expect(DiffPaneTextLayout.gutterDigitCount(maxLineNumber: 42) == 4)
    #expect(DiffPaneTextLayout.gutterDigitCount(maxLineNumber: 9999) == 4)
}

@Test func diffPaneTextLayoutGutterDigitCountGrowsForFiveDigits() {
    #expect(DiffPaneTextLayout.gutterDigitCount(maxLineNumber: 10000) == 5)
    #expect(DiffPaneTextLayout.gutterDigitCount(maxLineNumber: 123456) == 6)
}

@Test func diffPaneTextLayoutGutterLabelIsRightAligned() {
    #expect(DiffPaneTextLayout.gutterLabel(lineNumber: 1, digitCount: 4) == "   1")
    #expect(DiffPaneTextLayout.gutterLabel(lineNumber: 42, digitCount: 4) == "  42")
    #expect(DiffPaneTextLayout.gutterLabel(lineNumber: 10000, digitCount: 5) == "10000")
    #expect(DiffPaneTextLayout.gutterLabel(lineNumber: nil, digitCount: 4) == "    ")
}

@Test func diffPaneTextLayoutContentPlainTextExcludesLineNumbers() {
    let result = TextDiffer.compare("only", "only")
    let lines = SideBySideBuilder.build(from: result)
    let plain = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)

    #expect(plain == "only")
    #expect(plain.contains("│") == false)
    #expect(plain.hasSuffix("\n") == false)
}

@Test func diffPaneTextLayoutUtf16LocationMatchesContentPlainTextRowStarts() {
    let result = TextDiffer.compare("a\nold\nb\nold2\nc", "a\nnew\nb\nnew2\nc")
    let lines = SideBySideBuilder.build(from: result)

    let plainLeft = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left)
    let plainRight = DiffPaneTextLayout.contentPlainText(lines: lines, side: .right)
    let leftNS = plainLeft as NSString
    let rightNS = plainRight as NSString

    for row in 0..<lines.count {
        let leftLocation = DiffPaneTextLayout.utf16Location(forRow: row, in: lines, side: .left)
        let rightLocation = DiffPaneTextLayout.utf16Location(forRow: row, in: lines, side: .right)

        #expect(leftLocation == rowStartUTF16Offset(in: leftNS, row: row))
        #expect(rightLocation == rowStartUTF16Offset(in: rightNS, row: row))
        #expect(leftLocation <= leftNS.length)
        #expect(rightLocation <= rightNS.length)
    }
}

@Test func diffPaneTextLayoutUtf16LocationForFirstRowIsZero() {
    let result = TextDiffer.compare("alpha\nbeta", "alpha\ngamma")
    let lines = SideBySideBuilder.build(from: result)

    #expect(DiffPaneTextLayout.utf16Location(forRow: 0, in: lines, side: .left) == 0)
    #expect(DiffPaneTextLayout.utf16Location(forRow: 0, in: lines, side: .right) == 0)
}

@Test func diffPaneTextLayoutRowForUtf16LocationMatchesRowStarts() {
    let result = TextDiffer.compare("a\nold\nb\nold2\nc", "a\nnew\nb\nnew2\nc")
    let lines = SideBySideBuilder.build(from: result)

    for row in 0..<lines.count {
        for side: DiffPaneSide in [.left, .right] {
            let location = DiffPaneTextLayout.utf16Location(forRow: row, in: lines, side: side)
            #expect(
                DiffPaneTextLayout.row(forUtf16Location: location, in: lines, side: side) == row
            )
        }
    }
}

@Test func diffPaneTextLayoutRowForUtf16LocationWithinRowReturnsThatRow() {
    let result = TextDiffer.compare("alpha\nbeta", "alpha\ngamma")
    let lines = SideBySideBuilder.build(from: result)
    let midRowLocation = DiffPaneTextLayout.utf16Location(forRow: 1, in: lines, side: .left) + 2

    #expect(
        DiffPaneTextLayout.row(forUtf16Location: midRowLocation, in: lines, side: .left) == 1
    )
}

@Test func diffPaneTextLayoutRowForUtf16LocationPastEndClampsToLastRow() {
    let result = TextDiffer.compare("only", "only")
    let lines = SideBySideBuilder.build(from: result)
    let plain = DiffPaneTextLayout.contentPlainText(lines: lines, side: .left) as NSString

    #expect(
        DiffPaneTextLayout.row(
            forUtf16Location: plain.length + 100,
            in: lines,
            side: .left
        ) == lines.count - 1
    )
}

@Test func diffPaneTextLayoutRowForUtf16LocationOnEmptyPresentationReturnsZero() {
    #expect(
        DiffPaneTextLayout.row(forUtf16Location: 0, in: [], side: .left) == 0
    )
}

@Test func diffPaneTextLayoutGutterDigitCountFromLinesUsesSideMax() {
    let left = (1...12_000).map { "L\($0)" }.joined(separator: "\n")
    let right = (1...3).map { "R\($0)" }.joined(separator: "\n")
    let result = TextDiffer.compare(left, right)
    let lines = SideBySideBuilder.build(from: result)

    #expect(DiffPaneTextLayout.gutterDigitCount(lines: lines, side: .left) == 5)
    #expect(DiffPaneTextLayout.gutterDigitCount(lines: lines, side: .right) == 4)
}

@Test func diffPaneTextLayoutClampedVerticalOffsetShrinksWhenDocumentShortens() {
    // Document 200, visible 100 → maxY 100; current 150 must clamp to 100.
    let clamped = DiffPaneTextLayout.clampedVerticalOffset(
        currentY: 150,
        documentHeight: 200,
        visibleHeight: 100
    )
    #expect(clamped == 100)
}

@Test func diffPaneTextLayoutClampedVerticalOffsetKeepsInRangeValue() {
    let clamped = DiffPaneTextLayout.clampedVerticalOffset(
        currentY: 40,
        documentHeight: 200,
        visibleHeight: 100
    )
    #expect(clamped == 40)
}

@Test func diffPaneTextLayoutClampedVerticalOffsetRejectsNegative() {
    let clamped = DiffPaneTextLayout.clampedVerticalOffset(
        currentY: -12,
        documentHeight: 200,
        visibleHeight: 100
    )
    #expect(clamped == 0)
}

@Test func verticalOffsetAligningRowPlacesAtTop() {
    let offset = DiffPaneTextLayout.verticalOffsetAligningRow(
        lineMinY: 80,
        visibleHeight: 100,
        documentHeight: 400,
        anchorFractionInViewport: 0
    )
    #expect(offset == 80)
}

@Test func verticalOffsetAligningRowPlacesAtCenter() {
    let offset = DiffPaneTextLayout.verticalOffsetAligningRow(
        lineMinY: 80,
        visibleHeight: 100,
        documentHeight: 400,
        anchorFractionInViewport: 0.5
    )
    #expect(offset == 30)
}

@Test func verticalOffsetAligningRowPlacesAtBottom() {
    let offset = DiffPaneTextLayout.verticalOffsetAligningRow(
        lineMinY: 80,
        visibleHeight: 100,
        documentHeight: 400,
        anchorFractionInViewport: 1
    )
    #expect(offset == 0)
}

@Test func verticalOffsetAligningRowClampsPastDocumentEnd() {
    let offset = DiffPaneTextLayout.verticalOffsetAligningRow(
        lineMinY: 350,
        visibleHeight: 100,
        documentHeight: 400,
        anchorFractionInViewport: 0
    )
    #expect(offset == 300)
}

@Test func layoutDocumentHeightAddsTopAndBottomInsets() {
    #expect(
        DiffPaneTextLayout.layoutDocumentHeight(
            usedRectHeight: 100,
            textContainerInsetHeight: 8
        ) == 116
    )
}

@Test func utf16LocationForGutterRowMatchesGutterPlainText() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")
    let lines = SideBySideBuilder.build(from: result)
    let digitCount = DiffPaneTextLayout.gutterDigitCount(lines: lines, side: .left)
    let gutterPlain = lines.enumerated().map { index, line in
        DiffPaneTextLayout.contentRowString(
            text: DiffPaneTextLayout.gutterLabel(
                lineNumber: DiffPaneTextLayout.lineNumber(for: line, side: .left),
                digitCount: digitCount
            ),
            isLastRow: index == lines.count - 1
        )
    }.joined()

    let expected = rowStartUTF16Offset(in: gutterPlain as NSString, row: 2)
    let actual = DiffPaneTextLayout.utf16Location(
        forGutterRow: 2,
        in: lines,
        side: .left,
        digitCount: digitCount
    )
    #expect(actual == expected)
}

@Test func viewportAnchorFractionMeasuresRelativePosition() {
    #expect(
        DiffPaneTextLayout.viewportAnchorFraction(
            lineMinY: 50,
            visibleOriginY: 0,
            visibleHeight: 100
        ) == 0.5
    )
    #expect(
        DiffPaneTextLayout.viewportAnchorFraction(
            lineMinY: 0,
            visibleOriginY: 0,
            visibleHeight: 100
        ) == 0
    )
    #expect(
        DiffPaneTextLayout.viewportAnchorFraction(
            lineMinY: 100,
            visibleOriginY: 0,
            visibleHeight: 100
        ) == 1
    )
}

@Test func remappedPresentationRowKeepsCaretBeforeReplacement() {
    #expect(
        DiffPaneTextLayout.remappedPresentationRow(
            caretRow: 2,
            replacedStart: 5,
            replacedOldCount: 3,
            replacedNewCount: 1
        ) == 2
    )
}

@Test func remappedPresentationRowMovesCaretInsideToReplacementStart() {
    #expect(
        DiffPaneTextLayout.remappedPresentationRow(
            caretRow: 6,
            replacedStart: 5,
            replacedOldCount: 3,
            replacedNewCount: 1
        ) == 5
    )
    #expect(
        DiffPaneTextLayout.remappedPresentationRow(
            caretRow: 5,
            replacedStart: 5,
            replacedOldCount: 3,
            replacedNewCount: 1
        ) == 5
    )
}

@Test func remappedPresentationRowShiftsCaretAfterWhenReplacementShrinks() {
    // oldEnd = 8; caret at 10 → 5 + 1 + (10 - 8) = 8
    #expect(
        DiffPaneTextLayout.remappedPresentationRow(
            caretRow: 10,
            replacedStart: 5,
            replacedOldCount: 3,
            replacedNewCount: 1
        ) == 8
    )
}

@Test func remappedPresentationRowShiftsCaretAfterWhenReplacementGrows() {
    // oldEnd = 8; caret at 10 → 5 + 5 + (10 - 8) = 12
    #expect(
        DiffPaneTextLayout.remappedPresentationRow(
            caretRow: 10,
            replacedStart: 5,
            replacedOldCount: 3,
            replacedNewCount: 5
        ) == 12
    )
}

@Test func shouldApplyPaneContentSkipsOnlyWithUncommittedEditsAndUnchangedPresentation() {
    #expect(
        DiffPaneTextLayout.shouldApplyPaneContent(
            hasUncommittedEdits: true,
            shouldForceApply: false,
            presentationChanged: false,
            highlightChanged: false
        ) == false
    )
}

@Test func shouldApplyPaneContentSkipsWhenPresentationChangedWithUncommittedEdits() {
    #expect(
        DiffPaneTextLayout.shouldApplyPaneContent(
            hasUncommittedEdits: true,
            shouldForceApply: false,
            presentationChanged: true,
            highlightChanged: false
        ) == false
    )
}

@Test func shouldApplyPaneContentSkipsWhenHighlightChangedWithUncommittedEdits() {
    #expect(
        DiffPaneTextLayout.shouldApplyPaneContent(
            hasUncommittedEdits: true,
            shouldForceApply: false,
            presentationChanged: false,
            highlightChanged: true
        ) == false
    )
}

@Test func shouldApplyPaneContentWritesWhenFocusedWithoutUncommittedEdits() {
    #expect(
        DiffPaneTextLayout.shouldApplyPaneContent(
            hasUncommittedEdits: false,
            shouldForceApply: false,
            presentationChanged: false,
            highlightChanged: false
        ) == true
    )
}

@Test func shouldApplyPaneContentWritesWhenForceApply() {
    #expect(
        DiffPaneTextLayout.shouldApplyPaneContent(
            hasUncommittedEdits: true,
            shouldForceApply: true,
            presentationChanged: false,
            highlightChanged: false
        ) == true
    )
}

@Test func clampedPresentationRowReturnsNilWhenEmpty() {
    #expect(DiffPaneTextLayout.clampedPresentationRow(0, lineCount: 0) == nil)
    #expect(DiffPaneTextLayout.clampedPresentationRow(5, lineCount: 0) == nil)
}

@Test func clampedPresentationRowClampsAboveLastLine() {
    #expect(DiffPaneTextLayout.clampedPresentationRow(10, lineCount: 3) == 2)
}

@Test func clampedPresentationRowClampsBelowZero() {
    #expect(DiffPaneTextLayout.clampedPresentationRow(-1, lineCount: 3) == 0)
}

@Test func clampedPresentationRowKeepsInRangeRow() {
    #expect(DiffPaneTextLayout.clampedPresentationRow(1, lineCount: 3) == 1)
}

/// Returns the UTF-16 offset of the start of `row` by scanning newlines in `string`.
private func rowStartUTF16Offset(in string: NSString, row: Int) -> Int {
    if row <= 0 {
        return 0
    }
    var offset = 0
    var currentRow = 0
    while currentRow < row, offset < string.length {
        let remaining = NSRange(location: offset, length: string.length - offset)
        let found = string.range(of: "\n", options: [], range: remaining)
        guard found.location != NSNotFound else {
            return string.length
        }
        offset = found.location + found.length
        currentRow += 1
    }
    return offset
}
