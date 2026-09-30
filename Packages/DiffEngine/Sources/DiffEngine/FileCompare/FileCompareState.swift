/// Navigates between change hunks in a file comparison.
public struct HunkNavigator: Sendable, Equatable {
    public let hunkCount: Int
    public private(set) var currentIndex: Int?

    public init(hunkCount: Int) {
        self.hunkCount = hunkCount
        self.currentIndex = nil
    }

    /// Moves to the next hunk. Returns the new index, or `nil` when already at the last hunk.
    /// When nothing is selected, selects the first hunk.
    @discardableResult
    public mutating func goNext() -> Int? {
        guard hunkCount > 0 else {
            return nil
        }
        guard let currentIndex else {
            self.currentIndex = 0
            return 0
        }
        let next = currentIndex + 1
        guard next < hunkCount else {
            return nil
        }
        self.currentIndex = next
        return next
    }

    /// Moves to the previous hunk. Returns the new index, or `nil` when already at the first hunk.
    /// When nothing is selected, selects the last hunk.
    @discardableResult
    public mutating func goPrevious() -> Int? {
        guard hunkCount > 0 else {
            return nil
        }
        guard let currentIndex else {
            let last = hunkCount - 1
            self.currentIndex = last
            return last
        }
        let previous = currentIndex - 1
        guard previous >= 0 else {
            return nil
        }
        self.currentIndex = previous
        return previous
    }

    /// Selects a hunk by index. Returns the index on success, otherwise `nil` and leaves the current selection unchanged.
    @discardableResult
    public mutating func selectHunk(_ index: Int) -> Int? {
        guard index >= 0, index < hunkCount else {
            return nil
        }
        currentIndex = index
        return index
    }

    /// Clears the current hunk selection without changing `hunkCount`.
    public mutating func clearSelection() {
        currentIndex = nil
    }

    /// Selects the first hunk. Returns `0`, or `nil` when there are no hunks.
    @discardableResult
    public mutating func goFirst() -> Int? {
        selectHunk(0)
    }

    /// Selects the last hunk. Returns the last index, or `nil` when there are no hunks.
    @discardableResult
    public mutating func goLast() -> Int? {
        guard hunkCount > 0 else {
            return nil
        }
        return selectHunk(hunkCount - 1)
    }

    /// Returns the current hunk index. When nothing is selected but hunks exist, selects the first.
    @discardableResult
    public mutating func goCurrent() -> Int? {
        if let currentIndex {
            return currentIndex
        }
        return selectHunk(0)
    }
}

/// Snapshot of editable file-compare content for undo / redo.
public struct FileCompareEditSnapshot: Equatable, Sendable {
    public var leftText: String?
    public var rightText: String?
    public var leftFormat: TextFileFormat?
    public var rightFormat: TextFileFormat?
    public var isLeftDirty: Bool
    public var isRightDirty: Bool
    public var selectedHunkIndex: Int?

    public init(
        leftText: String?,
        rightText: String?,
        leftFormat: TextFileFormat? = nil,
        rightFormat: TextFileFormat? = nil,
        isLeftDirty: Bool,
        isRightDirty: Bool,
        selectedHunkIndex: Int?
    ) {
        self.leftText = leftText
        self.rightText = rightText
        self.leftFormat = leftFormat
        self.rightFormat = rightFormat
        self.isLeftDirty = isLeftDirty
        self.isRightDirty = isRightDirty
        self.selectedHunkIndex = selectedHunkIndex
    }
}

/// Mutable state for a two-pane file comparison session.
public struct FileCompareState: Sendable, Equatable {
    public var leftPath: String?
    public var rightPath: String?
    public private(set) var leftText: String?
    public private(set) var rightText: String?
    public private(set) var leftFormat: TextFileFormat?
    public private(set) var rightFormat: TextFileFormat?
    public private(set) var leftError: FileLoadError?
    public private(set) var rightError: FileLoadError?
    public private(set) var isLeftDirty: Bool
    public private(set) var isRightDirty: Bool
    public var options: DiffOptions {
        didSet { recompute(preservingHunkIndex: navigator.currentIndex) }
    }

    public private(set) var result: TextDiffResult?
    public private(set) var presentation: [SideBySideLine]
    public private(set) var navigator: HunkNavigator

    public init(options: DiffOptions = .default) {
        self.leftPath = nil
        self.rightPath = nil
        self.leftText = nil
        self.rightText = nil
        self.leftFormat = nil
        self.rightFormat = nil
        self.leftError = nil
        self.rightError = nil
        self.isLeftDirty = false
        self.isRightDirty = false
        self.options = options
        self.result = nil
        self.presentation = []
        self.navigator = HunkNavigator(hunkCount: 0)
    }

    public var canCompare: Bool {
        leftError == nil && rightError == nil && leftText != nil && rightText != nil
    }

    public var hasChanges: Bool {
        result?.hasChanges ?? false
    }

    public var hasUnsavedChanges: Bool {
        isLeftDirty || isRightDirty
    }

    /// Start row of the currently selected hunk in `presentation`, if any.
    public var currentHunkStartRow: Int? {
        guard let result, let index = navigator.currentIndex, result.hunks.indices.contains(index) else {
            return nil
        }
        return result.hunks[index].startRow
    }

    public mutating func setLeftText(
        _ text: String,
        path: String? = nil,
        format: TextFileFormat? = .default
    ) {
        leftText = text
        leftError = nil
        isLeftDirty = false
        if let format {
            leftFormat = format
        }
        if let path {
            leftPath = path
        }
        recompute(preservingHunkIndex: nil)
    }

    public mutating func setRightText(
        _ text: String,
        path: String? = nil,
        format: TextFileFormat? = .default
    ) {
        rightText = text
        rightError = nil
        isRightDirty = false
        if let format {
            rightFormat = format
        }
        if let path {
            rightPath = path
        }
        recompute(preservingHunkIndex: nil)
    }

    /// Applies user-edited file text for one side, marks that side dirty, and recomputes the diff.
    public mutating func applyEditedText(_ text: String, side: DiffPaneSide) {
        let preservedHunkIndex = navigator.currentIndex
        switch side {
        case .left:
            leftText = text
            leftError = nil
            isLeftDirty = true
        case .right:
            rightText = text
            rightError = nil
            isRightDirty = true
        }
        recompute(preservingHunkIndex: preservedHunkIndex)
        if preservedHunkIndex == nil {
            navigator.clearSelection()
        }
    }

    public mutating func setLeftFailure(_ error: FileLoadError, path: String? = nil) {
        leftText = nil
        leftFormat = nil
        leftError = error
        isLeftDirty = false
        if let path {
            leftPath = path
        }
        clearDiff()
    }

    public mutating func setRightFailure(_ error: FileLoadError, path: String? = nil) {
        rightText = nil
        rightFormat = nil
        rightError = error
        isRightDirty = false
        if let path {
            rightPath = path
        }
        clearDiff()
    }

    /// Selects a hunk by index. Returns the index on success.
    @discardableResult
    public mutating func selectHunk(_ index: Int) -> Int? {
        navigator.selectHunk(index)
    }

    public mutating func clearHunkSelection() {
        navigator.clearSelection()
    }

    /// Copies the current hunk onto `target` and clears hunk selection (does not advance).
    /// Returns caret remap info on success.
    @discardableResult
    public mutating func copyCurrentHunk(to target: MergeTarget) -> MergeCaretRemap? {
        guard let remap = applyCurrentHunk(to: target) else {
            return nil
        }
        navigator.clearSelection()
        return remap
    }

    /// Copies the current hunk onto `target`, then selects the following remaining hunk when one exists.
    /// Returns caret remap info on success.
    @discardableResult
    public mutating func copyCurrentHunkAndAdvance(to target: MergeTarget) -> MergeCaretRemap? {
        guard let hunkIndex = navigator.currentIndex else {
            return nil
        }
        guard let remap = applyCurrentHunk(to: target) else {
            return nil
        }
        if hunkIndex < navigator.hunkCount {
            _ = navigator.selectHunk(hunkIndex)
        } else {
            navigator.clearSelection()
        }
        return remap
    }

    public mutating func markLeftSaved() {
        isLeftDirty = false
    }

    public mutating func markRightSaved() {
        isRightDirty = false
    }

    /// Advances to the next hunk and returns its start row, or `nil` at the end.
    /// When no hunk is selected, uses `caretRow` (default 0) to pick the nearest hunk at or after the caret.
    @discardableResult
    public mutating func goNextHunk(caretRow: Int? = nil) -> Int? {
        if navigator.currentIndex != nil {
            guard navigator.goNext() != nil else {
                return nil
            }
            return currentHunkStartRow
        }
        guard let hunks = result?.hunks, !hunks.isEmpty else {
            return nil
        }
        let row = caretRow ?? 0
        if let index = DiffLocationLayout.hunkIndex(nextFromRow: row, in: hunks),
           navigator.selectHunk(index) != nil
        {
            return currentHunkStartRow
        }
        if let index = DiffLocationLayout.hunkIndex(nearestToRow: row, in: hunks),
           navigator.selectHunk(index) != nil
        {
            return currentHunkStartRow
        }
        return nil
    }

    /// Moves to the previous hunk and returns its start row, or `nil` at the start.
    /// When no hunk is selected, uses `caretRow` to pick the nearest hunk at or before the caret.
    @discardableResult
    public mutating func goPreviousHunk(caretRow: Int? = nil) -> Int? {
        if navigator.currentIndex != nil {
            guard navigator.goPrevious() != nil else {
                return nil
            }
            return currentHunkStartRow
        }
        guard let caretRow,
              let hunks = result?.hunks,
              let index = DiffLocationLayout.hunkIndex(previousFromRow: caretRow, in: hunks),
              navigator.selectHunk(index) != nil
        else {
            return nil
        }
        return currentHunkStartRow
    }

    /// Moves to the first hunk and returns its start row, or `nil` when there are no hunks.
    @discardableResult
    public mutating func goFirstHunk() -> Int? {
        guard navigator.goFirst() != nil else {
            return nil
        }
        return currentHunkStartRow
    }

    /// Moves to the last hunk and returns its start row, or `nil` when there are no hunks.
    @discardableResult
    public mutating func goLastHunk() -> Int? {
        guard navigator.goLast() != nil else {
            return nil
        }
        return currentHunkStartRow
    }

    /// Selects the hunk nearest to `caretRow` and returns its start row.
    @discardableResult
    public mutating func goNearestHunk(caretRow: Int?) -> Int? {
        guard let caretRow,
              let hunks = result?.hunks,
              let index = DiffLocationLayout.hunkIndex(nearestToRow: caretRow, in: hunks),
              navigator.selectHunk(index) != nil
        else {
            return nil
        }
        return currentHunkStartRow
    }

    /// Selects the hunk containing `caretRow` and returns its start row, or `nil` when the caret is outside all hunks.
    @discardableResult
    public mutating func goCurrentHunk(caretRow: Int?) -> Int? {
        guard let caretRow,
              let hunks = result?.hunks,
              let index = DiffLocationLayout.hunkIndex(containingRow: caretRow, in: hunks),
              navigator.selectHunk(index) != nil
        else {
            return nil
        }
        return currentHunkStartRow
    }

    public func canGoNextHunk(caretRow: Int?) -> Bool {
        guard let hunks = result?.hunks, !hunks.isEmpty else {
            return false
        }
        if let index = navigator.currentIndex {
            return index < hunks.count - 1
        }
        let row = caretRow ?? 0
        if DiffLocationLayout.hunkIndex(nextFromRow: row, in: hunks) != nil {
            return true
        }
        return DiffLocationLayout.hunkIndex(nearestToRow: row, in: hunks) != nil
    }

    public func canGoPreviousHunk(caretRow: Int?) -> Bool {
        guard let hunks = result?.hunks, !hunks.isEmpty else {
            return false
        }
        if let index = navigator.currentIndex {
            return index > 0
        }
        guard let caretRow else {
            return false
        }
        return DiffLocationLayout.hunkIndex(previousFromRow: caretRow, in: hunks) != nil
    }

    public func canGoCurrentHunk(caretRow: Int?) -> Bool {
        guard let caretRow, let hunks = result?.hunks else {
            return false
        }
        return DiffLocationLayout.hunkIndex(containingRow: caretRow, in: hunks) != nil
    }

    public func canGoNearestHunk(caretRow: Int?) -> Bool {
        guard let hunks = result?.hunks, !hunks.isEmpty else {
            return false
        }
        return caretRow != nil
    }

    /// Captures text, dirty flags, and current hunk selection for later restore.
    public func makeEditSnapshot() -> FileCompareEditSnapshot {
        FileCompareEditSnapshot(
            leftText: leftText,
            rightText: rightText,
            leftFormat: leftFormat,
            rightFormat: rightFormat,
            isLeftDirty: isLeftDirty,
            isRightDirty: isRightDirty,
            selectedHunkIndex: navigator.currentIndex
        )
    }

    /// Restores a previously captured edit snapshot and recomputes the presentation.
    public mutating func restoreEditSnapshot(_ snapshot: FileCompareEditSnapshot) {
        leftText = snapshot.leftText
        rightText = snapshot.rightText
        leftFormat = snapshot.leftFormat
        rightFormat = snapshot.rightFormat
        isLeftDirty = snapshot.isLeftDirty
        isRightDirty = snapshot.isRightDirty
        if snapshot.leftText != nil {
            leftError = nil
        }
        if snapshot.rightText != nil {
            rightError = nil
        }
        recompute(preservingHunkIndex: snapshot.selectedHunkIndex)
        if snapshot.selectedHunkIndex == nil {
            navigator.clearSelection()
        }
    }

    @discardableResult
    private mutating func applyCurrentHunk(to target: MergeTarget) -> MergeCaretRemap? {
        guard let result, let hunkIndex = navigator.currentIndex else {
            return nil
        }

        let direction: MergeDirection = target == .right ? .leftToRight : .rightToLeft
        guard let remap = MergeOperations.caretRemap(
            direction: direction,
            hunkIndex: hunkIndex,
            to: result
        ) else {
            return nil
        }
        guard let merged = MergeOperations.apply(
            direction: direction,
            hunkIndex: hunkIndex,
            to: result
        ) else {
            return nil
        }

        leftText = merged.leftText
        rightText = merged.rightText
        switch target {
        case .left:
            isLeftDirty = true
        case .right:
            isRightDirty = true
        }
        recompute(preservingHunkIndex: nil)
        navigator.clearSelection()
        return remap
    }

    private mutating func recompute(preservingHunkIndex: Int?) {
        guard let leftText, let rightText, leftError == nil, rightError == nil else {
            clearDiff()
            return
        }

        let diff = TextDiffer.compare(leftText, rightText, options: options)
        result = diff
        presentation = SideBySideBuilder.build(from: diff)
        navigator = HunkNavigator(hunkCount: diff.hunks.count)

        if diff.hunks.isEmpty {
            return
        }
        if let preservingHunkIndex {
            let clamped = min(max(preservingHunkIndex, 0), diff.hunks.count - 1)
            _ = navigator.selectHunk(clamped)
        }
    }

    private mutating func clearDiff() {
        result = nil
        presentation = []
        navigator = HunkNavigator(hunkCount: 0)
    }
}
