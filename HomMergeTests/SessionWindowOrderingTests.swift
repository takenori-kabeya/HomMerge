import XCTest
@testable import HomMerge

final class SessionWindowOrderingTests: XCTestCase {
    func testSnapshotsFrontToBackMatchesOrderedWindowNumbers() {
        let snap10 = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/10-left", rightPath: "/tmp/10-right")]
        )
        let snap20 = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/20-left", rightPath: "/tmp/20-right")]
        )
        let snap30 = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/30-left", rightPath: "/tmp/30-right")]
        )

        let result = SessionWindowOrdering.snapshotsFrontToBack(
            entries: [
                (windowNumber: 10, snapshot: snap10),
                (windowNumber: 20, snapshot: snap20),
                (windowNumber: 30, snapshot: snap30),
            ],
            orderedWindowNumbersFrontToBack: [30, 10, 20]
        )

        XCTAssertEqual(result, [snap30, snap10, snap20])
    }

    func testSnapshotsFrontToBackSkipsUnknownWindowNumbers() {
        let snap10 = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/a", rightPath: "/tmp/b")]
        )

        let result = SessionWindowOrdering.snapshotsFrontToBack(
            entries: [(windowNumber: 10, snapshot: snap10)],
            orderedWindowNumbersFrontToBack: [99, 10, 42]
        )

        XCTAssertEqual(result, [snap10])
    }

    func testSnapshotsFrontToBackReturnsEmptyForEmptyInput() {
        let result = SessionWindowOrdering.snapshotsFrontToBack(
            entries: [],
            orderedWindowNumbersFrontToBack: []
        )
        XCTAssertEqual(result, [])
    }

    func testSnapshotsFrontToBackKeepsLastSnapshotForDuplicateWindowNumbers() {
        let first = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/first", rightPath: nil)]
        )
        let last = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/last", rightPath: nil)]
        )
        let other = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/other", rightPath: nil)]
        )

        let result = SessionWindowOrdering.snapshotsFrontToBack(
            entries: [
                (windowNumber: 19587, snapshot: first),
                (windowNumber: 20, snapshot: other),
                (windowNumber: 19587, snapshot: last),
            ],
            orderedWindowNumbersFrontToBack: [19587, 20]
        )

        XCTAssertEqual(result, [last, other])
    }

    func testRestoreOpenOrderIsBackToFront() {
        let front = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/front", rightPath: nil)]
        )
        let middle = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/middle", rightPath: nil)]
        )
        let back = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/back", rightPath: nil)]
        )

        let result = SessionWindowOrdering.restoreOpenOrderFrontToBack([front, middle, back])
        XCTAssertEqual(result, [back, middle, front])
    }
}
