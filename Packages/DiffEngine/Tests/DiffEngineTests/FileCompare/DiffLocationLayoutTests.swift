import Foundation
import Testing
@testable import DiffEngine

@Test func diffLocationLayoutReturnsEmptyWhenNoRows() {
    let hunk = DiffHunk(startRow: 0, rowCount: 1)
    let frames = DiffLocationLayout.blockFrames(
        hunks: [hunk],
        totalRows: 0,
        barHeight: 100,
        minimumBlockHeight: 4
    )
    #expect(frames.isEmpty)
}

@Test func diffLocationLayoutReturnsEmptyWhenBarHeightNonPositive() {
    let hunk = DiffHunk(startRow: 0, rowCount: 1)
    let frames = DiffLocationLayout.blockFrames(
        hunks: [hunk],
        totalRows: 10,
        barHeight: 0,
        minimumBlockHeight: 4
    )
    #expect(frames.isEmpty)
}

@Test func diffLocationLayoutScalesBlocksProportionally() {
    let hunks = [
        DiffHunk(startRow: 0, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    let frames = DiffLocationLayout.blockFrames(
        hunks: hunks,
        totalRows: 10,
        barHeight: 100,
        minimumBlockHeight: 1
    )

    #expect(frames.count == 2)
    #expect(frames[0].originY == 0)
    #expect(frames[0].height == 20)
    #expect(frames[1].originY == 50)
    #expect(frames[1].height == 10)
}

@Test func diffLocationLayoutEnforcesMinimumBlockHeight() {
    let hunk = DiffHunk(startRow: 0, rowCount: 1)
    let frames = DiffLocationLayout.blockFrames(
        hunks: [hunk],
        totalRows: 100,
        barHeight: 100,
        minimumBlockHeight: 4
    )

    #expect(frames.count == 1)
    #expect(frames[0].height == 4)
    #expect(frames[0].originY == 0)
}

@Test func diffLocationLayoutClampsBlockInsideBar() {
    let hunk = DiffHunk(startRow: 99, rowCount: 1)
    let frames = DiffLocationLayout.blockFrames(
        hunks: [hunk],
        totalRows: 100,
        barHeight: 100,
        minimumBlockHeight: 8
    )

    #expect(frames.count == 1)
    #expect(frames[0].originY + frames[0].height <= 100)
    #expect(frames[0].height == 8)
}

@Test func diffLocationLayoutHunkIndexNearestToY() {
    let frames = [
        DiffLocationBlockFrame(hunkIndex: 0, originY: 0, height: 10),
        DiffLocationBlockFrame(hunkIndex: 1, originY: 50, height: 10),
    ]
    #expect(DiffLocationLayout.hunkIndex(nearestToY: 3, in: frames) == 0)
    #expect(DiffLocationLayout.hunkIndex(nearestToY: 55, in: frames) == 1)
    #expect(DiffLocationLayout.hunkIndex(nearestToY: 30, in: frames) == 0)
    #expect(DiffLocationLayout.hunkIndex(nearestToY: 40, in: frames) == 1)
    #expect(DiffLocationLayout.hunkIndex(nearestToY: 0, in: []) == nil)
}

@Test func diffLocationLayoutHunkIndexNearestToRowInsideHunkReturnsThatHunk() {
    let hunks = [
        DiffHunk(startRow: 0, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    #expect(DiffLocationLayout.hunkIndex(nearestToRow: 0, in: hunks) == 0)
    #expect(DiffLocationLayout.hunkIndex(nearestToRow: 1, in: hunks) == 0)
    #expect(DiffLocationLayout.hunkIndex(nearestToRow: 5, in: hunks) == 1)
}

@Test func diffLocationLayoutHunkIndexNearestToRowBetweenHunksPicksCloser() {
    let hunks = [
        DiffHunk(startRow: 0, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    #expect(DiffLocationLayout.hunkIndex(nearestToRow: 2, in: hunks) == 0)
    #expect(DiffLocationLayout.hunkIndex(nearestToRow: 4, in: hunks) == 1)
}

@Test func diffLocationLayoutHunkIndexNearestToRowBreaksTiesWithLowerIndex() {
    let hunks = [
        DiffHunk(startRow: 0, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    #expect(DiffLocationLayout.hunkIndex(nearestToRow: 3, in: hunks) == 0)
}

@Test func diffLocationLayoutHunkIndexNearestToRowReturnsNilForEmptyHunks() {
    #expect(DiffLocationLayout.hunkIndex(nearestToRow: 0, in: []) == nil)
}

@Test func diffLocationLayoutHunkIndexContainingRowReturnsHunkWhenInside() {
    let hunks = [
        DiffHunk(startRow: 1, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    #expect(DiffLocationLayout.hunkIndex(containingRow: 0, in: hunks) == nil)
    #expect(DiffLocationLayout.hunkIndex(containingRow: 1, in: hunks) == 0)
    #expect(DiffLocationLayout.hunkIndex(containingRow: 2, in: hunks) == 0)
    #expect(DiffLocationLayout.hunkIndex(containingRow: 3, in: hunks) == nil)
    #expect(DiffLocationLayout.hunkIndex(containingRow: 5, in: hunks) == 1)
}

@Test func diffLocationLayoutHunkIndexNextFromRowInsideHunkSelectsFollowingHunk() {
    let hunks = [
        DiffHunk(startRow: 1, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    #expect(DiffLocationLayout.hunkIndex(nextFromRow: 1, in: hunks) == 1)
    #expect(DiffLocationLayout.hunkIndex(nextFromRow: 2, in: hunks) == 1)
    #expect(DiffLocationLayout.hunkIndex(nextFromRow: 5, in: hunks) == nil)
}

@Test func diffLocationLayoutHunkIndexNextFromRowBetweenHunksSelectsNearestAhead() {
    let hunks = [
        DiffHunk(startRow: 1, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    #expect(DiffLocationLayout.hunkIndex(nextFromRow: 3, in: hunks) == 1)
    #expect(DiffLocationLayout.hunkIndex(nextFromRow: 0, in: hunks) == 0)
}

@Test func diffLocationLayoutHunkIndexPreviousFromRowInsideHunkSelectsPrecedingHunk() {
    let hunks = [
        DiffHunk(startRow: 1, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    #expect(DiffLocationLayout.hunkIndex(previousFromRow: 5, in: hunks) == 0)
    #expect(DiffLocationLayout.hunkIndex(previousFromRow: 1, in: hunks) == nil)
}

@Test func diffLocationLayoutHunkIndexPreviousFromRowBetweenHunksSelectsNearestBehind() {
    let hunks = [
        DiffHunk(startRow: 1, rowCount: 2),
        DiffHunk(startRow: 5, rowCount: 1),
    ]
    #expect(DiffLocationLayout.hunkIndex(previousFromRow: 3, in: hunks) == 0)
    #expect(DiffLocationLayout.hunkIndex(previousFromRow: 6, in: hunks) == 1)
}

@Test func diffLocationLayoutViewportReturnsNilForInvalidInput() {
    #expect(
        DiffLocationLayout.viewportFrame(
            visibleOriginY: 0,
            visibleHeight: 50,
            documentHeight: 0,
            barHeight: 100
        ) == nil
    )
    #expect(
        DiffLocationLayout.viewportFrame(
            visibleOriginY: 0,
            visibleHeight: 50,
            documentHeight: 100,
            barHeight: 0
        ) == nil
    )
}

@Test func diffLocationLayoutViewportCoversFullBarWhenDocumentFits() {
    let frame = DiffLocationLayout.viewportFrame(
        visibleOriginY: 0,
        visibleHeight: 200,
        documentHeight: 150,
        barHeight: 100
    )
    #expect(frame == DiffLocationViewportFrame(originY: 0, height: 100))
}

@Test func diffLocationLayoutViewportScalesProportionallyAtTop() {
    let frame = DiffLocationLayout.viewportFrame(
        visibleOriginY: 0,
        visibleHeight: 50,
        documentHeight: 200,
        barHeight: 100,
        minimumHeight: 1
    )
    #expect(frame == DiffLocationViewportFrame(originY: 0, height: 25))
}

@Test func diffLocationLayoutViewportScalesProportionallyInMiddle() {
    let frame = DiffLocationLayout.viewportFrame(
        visibleOriginY: 75,
        visibleHeight: 50,
        documentHeight: 200,
        barHeight: 100,
        minimumHeight: 1
    )
    #expect(frame == DiffLocationViewportFrame(originY: 37.5, height: 25))
}

@Test func diffLocationLayoutViewportClampsAtBottom() {
    let frame = DiffLocationLayout.viewportFrame(
        visibleOriginY: 160,
        visibleHeight: 50,
        documentHeight: 200,
        barHeight: 100,
        minimumHeight: 1
    )
    #expect(frame == DiffLocationViewportFrame(originY: 75, height: 25))
}

@Test func diffLocationLayoutViewportEnforcesMinimumHeight() {
    let frame = DiffLocationLayout.viewportFrame(
        visibleOriginY: 0,
        visibleHeight: 1,
        documentHeight: 10_000,
        barHeight: 100,
        minimumHeight: 2
    )
    #expect(frame == DiffLocationViewportFrame(originY: 0, height: 2))
}
