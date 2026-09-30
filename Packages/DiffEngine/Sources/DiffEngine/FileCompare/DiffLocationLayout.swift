import Foundation

/// Vertical placement of one hunk marker inside a location bar.
public struct DiffLocationBlockFrame: Sendable, Equatable {
    public let hunkIndex: Int
    /// Top of the block in bar coordinates (y increases downward).
    public let originY: Double
    public let height: Double

    public init(hunkIndex: Int, originY: Double, height: Double) {
        self.hunkIndex = hunkIndex
        self.originY = originY
        self.height = height
    }

    public var midY: Double {
        originY + height / 2
    }
}

/// Vertical placement of the visible pane viewport inside a location bar.
public struct DiffLocationViewportFrame: Sendable, Equatable {
    /// Top of the viewport band in bar coordinates (y increases downward).
    public let originY: Double
    public let height: Double

    public init(originY: Double, height: Double) {
        self.originY = originY
        self.height = height
    }
}

/// Computes proportional marker frames for a file-compare location bar.
public enum DiffLocationLayout {
    /// Returns one frame per hunk, scaled to `barHeight`.
    public static func blockFrames(
        hunks: [DiffHunk],
        totalRows: Int,
        barHeight: Double,
        minimumBlockHeight: Double = 4
    ) -> [DiffLocationBlockFrame] {
        guard totalRows > 0, barHeight > 0, !hunks.isEmpty else {
            return []
        }

        return hunks.enumerated().map { index, hunk in
            let rawY = (Double(hunk.startRow) / Double(totalRows)) * barHeight
            let rawHeight = (Double(hunk.rowCount) / Double(totalRows)) * barHeight
            let height = min(max(rawHeight, minimumBlockHeight), barHeight)
            let maxOrigin = max(barHeight - height, 0)
            let originY = min(max(rawY, 0), maxOrigin)
            return DiffLocationBlockFrame(hunkIndex: index, originY: originY, height: height)
        }
    }

    /// Picks the hunk whose block center is closest to `y`, or `nil` when `frames` is empty.
    public static func hunkIndex(nearestToY y: Double, in frames: [DiffLocationBlockFrame]) -> Int? {
        guard !frames.isEmpty else {
            return nil
        }
        return frames.min(by: { abs($0.midY - y) < abs($1.midY - y) })?.hunkIndex
    }

    /// Picks the hunk whose row range is closest to `row`, or `nil` when `hunks` is empty.
    /// Rows inside a hunk have distance zero. Equal distances prefer the lower hunk index.
    public static func hunkIndex(nearestToRow row: Int, in hunks: [DiffHunk]) -> Int? {
        guard !hunks.isEmpty else {
            return nil
        }
        return hunks.enumerated().min(by: {
            distance(from: row, to: $0.element) < distance(from: row, to: $1.element)
        })?.offset
    }

    /// Picks the nearest hunk at or after `row`. When `row` is inside a hunk, returns the following hunk.
    public static func hunkIndex(nextFromRow row: Int, in hunks: [DiffHunk]) -> Int? {
        guard !hunks.isEmpty else {
            return nil
        }
        if let containing = hunkIndex(containingRow: row, in: hunks) {
            let next = containing + 1
            return next < hunks.count ? next : nil
        }
        return hunks.enumerated()
            .filter { $0.element.startRow >= row }
            .min(by: { $0.element.startRow < $1.element.startRow })?
            .offset
    }

    /// Picks the nearest hunk at or before `row`. When `row` is inside a hunk, returns the preceding hunk.
    public static func hunkIndex(previousFromRow row: Int, in hunks: [DiffHunk]) -> Int? {
        guard !hunks.isEmpty else {
            return nil
        }
        if let containing = hunkIndex(containingRow: row, in: hunks) {
            return containing > 0 ? containing - 1 : nil
        }
        return hunks.enumerated()
            .filter { $0.element.startRow + $0.element.rowCount - 1 < row }
            .max(by: { $0.element.startRow < $1.element.startRow })?
            .offset
    }

    /// Returns the hunk index containing `row`, or `nil` when `row` is outside every hunk.
    public static func hunkIndex(containingRow row: Int, in hunks: [DiffHunk]) -> Int? {
        hunks.enumerated().first(where: { _, hunk in
            let end = hunk.startRow + hunk.rowCount - 1
            return row >= hunk.startRow && row <= end
        })?.offset
    }

    private static func distance(from row: Int, to hunk: DiffHunk) -> Int {
        let start = hunk.startRow
        let end = hunk.startRow + hunk.rowCount - 1
        if row < start {
            return start - row
        }
        if row > end {
            return row - end
        }
        return 0
    }

    /// Maps the pane's visible document range onto a location bar band.
    public static func viewportFrame(
        visibleOriginY: Double,
        visibleHeight: Double,
        documentHeight: Double,
        barHeight: Double,
        minimumHeight: Double = 2
    ) -> DiffLocationViewportFrame? {
        guard documentHeight > 0, barHeight > 0 else {
            return nil
        }

        if documentHeight <= visibleHeight {
            return DiffLocationViewportFrame(originY: 0, height: barHeight)
        }

        let rawOriginY = (visibleOriginY / documentHeight) * barHeight
        let rawHeight = (visibleHeight / documentHeight) * barHeight
        let height = min(max(rawHeight, minimumHeight), barHeight)
        let maxOrigin = max(barHeight - height, 0)
        let originY = min(max(rawOriginY, 0), maxOrigin)
        return DiffLocationViewportFrame(originY: originY, height: height)
    }
}
