import Testing
@testable import DiffEngine

@Test func identicalTextsProduceOnlyEqualRows() {
    let result = TextDiffer.compare("alpha\nbeta\n", "alpha\nbeta\n")

    #expect(result.leftLines == ["alpha", "beta"])
    #expect(result.rightLines == ["alpha", "beta"])
    #expect(result.hasChanges == false)
    #expect(result.alignedRows.count == 2)
    #expect(result.alignedRows[0] == DiffRow(kind: .equal, leftIndex: 0, rightIndex: 0))
    #expect(result.alignedRows[1] == DiffRow(kind: .equal, leftIndex: 1, rightIndex: 1))
    #expect(result.hunks.isEmpty)
}

@Test func emptyTextsProduceNoRows() {
    let result = TextDiffer.compare("", "")

    #expect(result.leftLines.isEmpty)
    #expect(result.rightLines.isEmpty)
    #expect(result.alignedRows.isEmpty)
    #expect(result.hasChanges == false)
}

@Test func emptyLeftIsAllInserts() {
    let result = TextDiffer.compare("", "one\ntwo")

    #expect(result.leftLines.isEmpty)
    #expect(result.rightLines == ["one", "two"])
    #expect(result.alignedRows.map(\.kind) == [.insert, .insert])
    #expect(result.alignedRows[0].leftIndex == nil)
    #expect(result.alignedRows[0].rightIndex == 0)
    #expect(result.alignedRows[1].rightIndex == 1)
    #expect(result.hasChanges == true)
    #expect(result.hunks.count == 1)
    #expect(result.hunks[0].startRow == 0)
    #expect(result.hunks[0].rowCount == 2)
}

@Test func emptyRightIsAllDeletes() {
    let result = TextDiffer.compare("one\ntwo", "")

    #expect(result.alignedRows.map(\.kind) == [.delete, .delete])
    #expect(result.alignedRows[0].leftIndex == 0)
    #expect(result.alignedRows[0].rightIndex == nil)
    #expect(result.hunks.count == 1)
}

@Test func trailingNewlineDoesNotCreateExtraEmptyLine() {
    let result = TextDiffer.compare("hello\n", "hello")

    // Trailing-newline difference is a diff; line content stays "hello", with a virtual blank line on the side that has the newline.
    #expect(result.leftLines == ["hello", ""])
    #expect(result.rightLines == ["hello"])
    #expect(result.hasChanges == true)
}

@Test func trailingNewlineMismatchIsAChange() {
    let result = TextDiffer.compare("hello\n", "hello")

    #expect(result.leftEndsWithNewline == true)
    #expect(result.rightEndsWithNewline == false)
    #expect(result.hasChanges == true)
    #expect(result.leftLines == ["hello", ""])
    #expect(result.rightLines == ["hello"])
    #expect(result.alignedRows.map(\.kind) == [.equal, .delete])
    #expect(result.alignedRows[1].leftIndex == 1)
    #expect(result.alignedRows[1].rightIndex == nil)
    #expect(result.hunks.count == 1)
}

@Test func matchingTrailingNewlinesAreIdentical() {
    let result = TextDiffer.compare("hello\n", "hello\n")

    #expect(result.leftEndsWithNewline == true)
    #expect(result.rightEndsWithNewline == true)
    #expect(result.hasChanges == false)
    #expect(result.leftLines == ["hello"])
    #expect(result.rightLines == ["hello"])
    #expect(result.alignedRows.map(\.kind) == [.equal])
}

@Test func emptyVersusSingleNewlineIsAChange() {
    let result = TextDiffer.compare("", "\n")

    #expect(result.leftEndsWithNewline == false)
    #expect(result.rightEndsWithNewline == true)
    #expect(result.hasChanges == true)
    #expect(result.leftLines.isEmpty)
    // "\n" splits to one blank content line; no extra virtual trailing row.
    #expect(result.rightLines == [""])
    #expect(result.alignedRows.map(\.kind) == [.insert])
}

@Test func lineSplitterReportsEndsWithNewline() {
    let empty = LineSplitter.splitDetailed("")
    #expect(empty.lines == [])
    #expect(empty.endsWithNewline == false)

    let noNewline = LineSplitter.splitDetailed("x")
    #expect(noNewline.lines == ["x"])
    #expect(noNewline.endsWithNewline == false)

    let withNewline = LineSplitter.splitDetailed("x\n")
    #expect(withNewline.lines == ["x"])
    #expect(withNewline.endsWithNewline == true)

    let onlyNewline = LineSplitter.splitDetailed("\n")
    #expect(onlyNewline.lines == [""])
    #expect(onlyNewline.endsWithNewline == true)
}

@Test func middleBlankLineIsPreservedInLineSplit() {
    let result = TextDiffer.compare("a\n\nb", "a\n\nb")

    #expect(result.leftLines == ["a", "", "b"])
    #expect(result.hasChanges == false)
}

@Test func insertedLineInMiddle() {
    let result = TextDiffer.compare("a\nc", "a\nb\nc")

    #expect(result.alignedRows.map(\.kind) == [.equal, .insert, .equal])
    #expect(result.alignedRows[1].leftIndex == nil)
    #expect(result.alignedRows[1].rightIndex == 1)
    #expect(result.alignedRows[2].leftIndex == 1)
    #expect(result.alignedRows[2].rightIndex == 2)
    #expect(result.hunks.count == 1)
    #expect(result.hunks[0].startRow == 1)
    #expect(result.hunks[0].rowCount == 1)
}

@Test func deletedLineInMiddle() {
    let result = TextDiffer.compare("a\nb\nc", "a\nc")

    #expect(result.alignedRows.map(\.kind) == [.equal, .delete, .equal])
    #expect(result.alignedRows[1].leftIndex == 1)
    #expect(result.alignedRows[1].rightIndex == nil)
}

@Test func modifiedLineIsPairedAsModify() {
    let result = TextDiffer.compare("hello world", "hello swift")

    #expect(result.alignedRows.count == 1)
    #expect(result.alignedRows[0].kind == .modify)
    #expect(result.alignedRows[0].leftIndex == 0)
    #expect(result.alignedRows[0].rightIndex == 0)
    #expect(result.hunks.count == 1)
}

@Test func modifiedLineIncludesInlineSpans() {
    let result = TextDiffer.compare("hello world", "hello swift")
    let row = result.alignedRows[0]

    #expect(row.kind == .modify)
    #expect(row.leftInlineSpans == [
        InlineSpan(start: 0, end: 6, kind: .equal),
        InlineSpan(start: 6, end: 11, kind: .delete),
    ])
    #expect(row.rightInlineSpans == [
        InlineSpan(start: 0, end: 6, kind: .equal),
        InlineSpan(start: 6, end: 11, kind: .insert),
    ])
}

@Test func equalRowsHaveNoInlineSpans() {
    let result = TextDiffer.compare("same", "same")

    #expect(result.alignedRows[0].leftInlineSpans.isEmpty)
    #expect(result.alignedRows[0].rightInlineSpans.isEmpty)
}

@Test func pureInsertRowHasNoInlineSpans() {
    let result = TextDiffer.compare("keep", "keep\nextra")
    let insert = result.alignedRows[1]

    #expect(insert.kind == .insert)
    #expect(insert.leftInlineSpans.isEmpty)
    #expect(insert.rightInlineSpans.isEmpty)
}

@Test func pureDeleteRowHasNoInlineSpans() {
    let result = TextDiffer.compare("keep\ngone", "keep")
    let delete = result.alignedRows[1]

    #expect(delete.kind == .delete)
    #expect(delete.leftInlineSpans.isEmpty)
    #expect(delete.rightInlineSpans.isEmpty)
}

@Test func ignoreWhitespaceTreatsSpacingDifferencesAsEqual() {
    let options = DiffOptions(ignoreWhitespace: true)
    let result = TextDiffer.compare("a b\nc  d", "a  b\nc d", options: options)

    #expect(result.hasChanges == false)
    #expect(result.alignedRows.map(\.kind) == [.equal, .equal])
    // Original texts are preserved for display
    #expect(result.leftLines == ["a b", "c  d"])
    #expect(result.rightLines == ["a  b", "c d"])
}

@Test func ignoreWhitespaceStillDetectsRealContentChange() {
    let options = DiffOptions(ignoreWhitespace: true)
    let result = TextDiffer.compare("a b", "a x", options: options)

    #expect(result.hasChanges == true)
    #expect(result.alignedRows[0].kind == .modify)
}

@Test func ignoreBlankLinesIgnoresBlankOnlyDifferences() {
    let options = DiffOptions(ignoreBlankLines: true)
    let result = TextDiffer.compare("a\n\nb", "a\nb", options: options)

    #expect(result.hasChanges == false)
    #expect(result.alignedRows.map(\.kind) == [.equal, .equal])
    #expect(result.alignedRows[0].leftIndex == 0)
    #expect(result.alignedRows[0].rightIndex == 0)
    #expect(result.alignedRows[1].leftIndex == 2)
    #expect(result.alignedRows[1].rightIndex == 1)
}

@Test func ignoreBlankLinesStillDetectsContentChange() {
    let options = DiffOptions(ignoreBlankLines: true)
    let result = TextDiffer.compare("a\n\nb", "a\n\nx", options: options)

    #expect(result.hasChanges == true)
    #expect(result.alignedRows.contains { $0.kind == .modify || $0.kind == .delete || $0.kind == .insert })
}

@Test func multipleHunksAreSeparatedByEqualRows() {
    let result = TextDiffer.compare(
        "a\nold1\nb\nold2\nc",
        "a\nnew1\nb\nnew2\nc"
    )

    #expect(result.alignedRows.map(\.kind) == [
        .equal, .modify, .equal, .modify, .equal,
    ])
    #expect(result.hunks.count == 2)
    #expect(result.hunks[0].startRow == 1)
    #expect(result.hunks[0].rowCount == 1)
    #expect(result.hunks[1].startRow == 3)
    #expect(result.hunks[1].rowCount == 1)
}

@Test func replaceBlockPairsDeletesAndInsertsAsModifiesThenRemainder() {
    let result = TextDiffer.compare(
        "a\nL1\nL2\nb",
        "a\nR1\nb"
    )

    #expect(result.alignedRows.map(\.kind) == [
        .equal, .modify, .delete, .equal,
    ])
    #expect(result.alignedRows[1].leftIndex == 1)
    #expect(result.alignedRows[1].rightIndex == 1)
    #expect(result.alignedRows[2].leftIndex == 2)
    #expect(result.alignedRows[2].rightIndex == nil)
}

@Test func computeInlineDiffsCanBeDisabled() {
    let options = DiffOptions(computeInlineDiffs: false)
    let result = TextDiffer.compare("hello world", "hello swift", options: options)

    #expect(result.alignedRows[0].kind == .modify)
    #expect(result.alignedRows[0].leftInlineSpans.isEmpty)
    #expect(result.alignedRows[0].rightInlineSpans.isEmpty)
}

@Test func lineSplitterExposesPublicAPI() {
    #expect(LineSplitter.split("") == [])
    #expect(LineSplitter.split("x") == ["x"])
    #expect(LineSplitter.split("x\n") == ["x"])
    #expect(LineSplitter.split("x\ny") == ["x", "y"])
    #expect(LineSplitter.split("x\n\ny") == ["x", "", "y"])
}
