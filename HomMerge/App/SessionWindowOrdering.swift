import Foundation

enum SessionWindowOrdering {
    /// Orders snapshots to match `orderedWindowNumbersFrontToBack` (front → back).
    /// Window numbers that are not present in `entries` are skipped.
    static func snapshotsFrontToBack(
        entries: [(windowNumber: Int, snapshot: WindowSnapshot)],
        orderedWindowNumbersFrontToBack: [Int]
    ) -> [WindowSnapshot] {
        let byNumber = Dictionary(
            entries.map { ($0.windowNumber, $0.snapshot) },
            uniquingKeysWith: { _, last in last }
        )
        return orderedWindowNumbersFrontToBack.compactMap { byNumber[$0] }
    }

    /// Converts a front→back snapshot list into the open order for restore (back→front).
    /// Later-opened windows become frontmost under SwiftUI `openWindow`.
    static func restoreOpenOrderFrontToBack(_ windowsFrontToBack: [WindowSnapshot]) -> [WindowSnapshot] {
        Array(windowsFrontToBack.reversed())
    }
}
