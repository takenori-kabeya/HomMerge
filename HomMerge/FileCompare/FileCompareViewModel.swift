import AppKit
import DiffEngine
import Foundation
import Observation

@Observable
@MainActor
final class FileCompareViewModel {
    private(set) var state = FileCompareState()
    private(set) var scrollToRow: Int?
    private(set) var scrollToken = 0
    /// Bumped after Copy / Refresh so panes force-rewrite their attributed strings.
    private(set) var paneApplyToken = 0
    /// Bumped to select the hunk nearest to the caret in the focused pane.
    private(set) var nearestHunkSelectToken = 0
    /// Consumed by DiffPanePair after Copy to remap the caret across the replaced hunk.
    private(set) var pendingCaretRemap: MergeCaretRemap?
    /// Consumed by DiffPanePair after Refresh / Copy / hunk nav to place the caret at a presentation row start.
    /// `focus` is false for hunk navigation (resign pane first responder).
    private(set) var pendingCaretLineStartRestore: (side: DiffPaneSide, row: Int, focus: Bool)?
    /// Bumped with `pendingCaretLineStartRestore` so DiffPanePair applies the placement.
    private(set) var caretLineStartRestoreToken = 0
    /// Last caret presentation row reported by the panes (survives toolbar clicks).
    private(set) var lastKnownCaretRow: Int?
    private(set) var lastKnownCaretSide: DiffPaneSide?
    /// Relative caret position in the viewport (0 = top, 1 = bottom) for Refresh scroll restore.
    private(set) var lastKnownCaretViewportFraction: CGFloat?
    /// Optional viewport anchor used with the latest `scrollToRow` request (`nil` → default 0.25).
    private(set) var scrollViewportAnchorFraction: CGFloat?
    private(set) var lastSaveError: String?
    /// True while a pane has uncommitted keystrokes (not merely focus/caret).
    private(set) var isEditingPane = false
    /// Sides with keystrokes/pastes not yet committed via focus leave / Save flush.
    private(set) var uncommittedEditSides: Set<DiffPaneSide> = []
    /// True while either diff pane is focused, or a caret row was remembered after focus left.
    private(set) var isPaneFocused = false
    /// Bumped when the merge undo stack changes so SwiftUI menus refresh `canMergeUndo`.
    private(set) var mergeUndoRevision = 0
    let undoManager = UndoManager()

    var canMergeUndo: Bool {
        undoManager.canUndo
    }

    var canMergeRedo: Bool {
        undoManager.canRedo
    }

    func undoMerge() {
        undoManager.undo()
    }

    func redoMerge() {
        undoManager.redo()
    }

    var leftTitle: String {
        let name = state.leftPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Left"
        return state.isLeftDirty ? "\(name) •" : name
    }

    var rightTitle: String {
        let name = state.rightPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Right"
        return state.isRightDirty ? "\(name) •" : name
    }

    var showsFormatStatusBar: Bool {
        state.leftPath != nil || state.rightPath != nil
    }

    var leftFormatStatusText: String? {
        state.leftFormat?.statusDescription
    }

    var rightFormatStatusText: String? {
        state.rightFormat?.statusDescription
    }

    var statusText: String {
        if let lastSaveError {
            return lastSaveError
        }
        if let leftError = state.leftError {
            return "Left: \(describe(leftError))"
        }
        if let rightError = state.rightError {
            return "Right: \(describe(rightError))"
        }
        guard state.canCompare else {
            return "Open files on both sides to compare"
        }

        var parts: [String] = []
        if state.hasChanges {
            let hunks = state.navigator.hunkCount
            if let index = state.navigator.currentIndex {
                parts.append("\(hunks) difference\(hunks == 1 ? "" : "s") — \(index + 1) of \(hunks)")
            } else {
                parts.append("\(hunks) difference\(hunks == 1 ? "" : "s")")
            }
        } else {
            parts.append("Files are identical")
        }
        if state.hasUnsavedChanges {
            var dirty: [String] = []
            if state.isLeftDirty { dirty.append("left") }
            if state.isRightDirty { dirty.append("right") }
            parts.append("unsaved: \(dirty.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }

    var highlightedRowRange: Range<Int>? {
        guard let result = state.result,
              let index = state.navigator.currentIndex,
              result.hunks.indices.contains(index)
        else {
            return nil
        }
        let hunk = result.hunks[index]
        return hunk.startRow ..< (hunk.startRow + hunk.rowCount)
    }

    var locationHunks: [DiffHunk] {
        state.result?.hunks ?? []
    }

    var currentHunkIndex: Int? {
        state.navigator.currentIndex
    }

    /// Copy is allowed with caret focus; blocked only during uncommitted pane typing.
    var canCopyHunk: Bool {
        !isEditingPane && state.navigator.currentIndex != nil
    }

    var canSelectNearestHunkToCaret: Bool {
        isPaneFocused && state.canGoNearestHunk(caretRow: caretPresentationRow)
    }

    var canGoNextDifference: Bool {
        state.canGoNextHunk(caretRow: caretPresentationRow)
    }

    var canGoPreviousDifference: Bool {
        state.canGoPreviousHunk(caretRow: caretPresentationRow)
    }

    var canGoCurrentDifference: Bool {
        state.canGoCurrentHunk(caretRow: caretPresentationRow)
    }

    /// Clamped presentation row for navigation. Defaults to row 0 before the user focuses a pane.
    var caretPresentationRow: Int? {
        guard state.canCompare, !state.presentation.isEmpty else {
            return nil
        }
        let row = lastKnownCaretRow ?? 0
        return DiffPaneTextLayout.clampedPresentationRow(
            row,
            lineCount: state.presentation.count
        )
    }

    var canSaveLeft: Bool {
        state.leftText != nil && (state.isLeftDirty || uncommittedEditSides.contains(.left))
    }

    var canSaveRight: Bool {
        state.rightText != nil && (state.isRightDirty || uncommittedEditSides.contains(.right))
    }

    var ignoreWhitespace: Bool {
        get { state.options.ignoreWhitespace }
        set {
            var options = state.options
            options.ignoreWhitespace = newValue
            state.options = options
        }
    }

    var ignoreBlankLines: Bool {
        get { state.options.ignoreBlankLines }
        set {
            var options = state.options
            options.ignoreBlankLines = newValue
            state.options = options
        }
    }

    func load(url: URL, side: DiffPaneSide) {
        switch side {
        case .left:
            if state.isLeftDirty, !confirmDiscard(sideName: "left") {
                return
            }
        case .right:
            if state.isRightDirty, !confirmDiscard(sideName: "right") {
                return
            }
        }

        lastSaveError = nil
        clearMergeUndoHistory()
        let path = url.path
        do {
            let loaded = try FileContentLoader.loadFile(from: url)
            switch side {
            case .left:
                state.setLeftText(loaded.text, path: path, format: loaded.format)
            case .right:
                state.setRightText(loaded.text, path: path, format: loaded.format)
            }
            scrollToRow = nil
            scrollViewportAnchorFraction = nil
        } catch let error as FileLoadError {
            switch side {
            case .left:
                state.setLeftFailure(error, path: path)
            case .right:
                state.setRightFailure(error, path: path)
            }
            scrollToRow = nil
        } catch {
            switch side {
            case .left:
                state.setLeftFailure(.unreadable, path: path)
            case .right:
                state.setRightFailure(.unreadable, path: path)
            }
            scrollToRow = nil
        }
    }

    func openLeftFile() {
        guard let url = chooseFile(title: "Open Left File") else { return }
        load(url: url, side: .left)
    }

    func openRightFile() {
        guard let url = chooseFile(title: "Open Right File") else { return }
        load(url: url, side: .right)
    }

    /// Reloads both sides from disk and recomputes the diff.
    func refresh() {
        guard let leftPath = state.leftPath, let rightPath = state.rightPath else { return }
        if state.hasUnsavedChanges, !confirmDiscardRefresh() {
            return
        }
        let restoreRow = lastKnownCaretRow
        let restoreSide = lastKnownCaretSide ?? .left
        clearMergeUndoHistory()
        reloadFromDisk(path: leftPath, side: .left)
        reloadFromDisk(path: rightPath, side: .right)
        paneApplyToken += 1
        if let restoreRow,
           let row = DiffPaneTextLayout.clampedPresentationRow(
            restoreRow,
            lineCount: state.presentation.count
           )
        {
            pendingCaretLineStartRestore = (side: restoreSide, row: row, focus: true)
            caretLineStartRestoreToken += 1
            requestScroll(to: row, viewportAnchorFraction: lastKnownCaretViewportFraction)
            if let index = DiffLocationLayout.hunkIndex(nearestToRow: row, in: locationHunks) {
                _ = state.selectHunk(index)
            }
        } else {
            state.clearHunkSelection()
            scrollToRow = nil
            scrollViewportAnchorFraction = nil
        }
    }

    /// Seeds both panes from in-memory text (also used by unit tests).
    func seedComparison(leftText: String, rightText: String, leftPath: String? = nil, rightPath: String? = nil) {
        lastSaveError = nil
        clearMergeUndoHistory()
        state.setLeftText(leftText, path: leftPath)
        state.setRightText(rightText, path: rightPath)
        scrollToRow = nil
        scrollViewportAnchorFraction = nil
    }

    func copyHunkToRight() {
        _ = performMergeCopy(actionName: "Copy Difference to Right", targetSide: .right) {
            state.copyCurrentHunk(to: .right)
        }
    }

    func copyHunkToLeft() {
        _ = performMergeCopy(actionName: "Copy Difference to Left", targetSide: .left) {
            state.copyCurrentHunk(to: .left)
        }
    }

    func copyHunkToRightAndNext() {
        let didCopy = performMergeCopy(actionName: "Copy Difference to Right", targetSide: .right) {
            state.copyCurrentHunk(to: .right)
        }
        if didCopy {
            goNextDifference()
        }
    }

    func copyHunkToLeftAndNext() {
        let didCopy = performMergeCopy(actionName: "Copy Difference to Left", targetSide: .left) {
            state.copyCurrentHunk(to: .left)
        }
        if didCopy {
            goNextDifference()
        }
    }

    func saveLeft() {
        save(side: .left)
    }

    func saveRight() {
        save(side: .right)
    }

    func goNextDifference() {
        if let row = state.goNextHunk(caretRow: caretPresentationRow) {
            navigateToHunk(startRow: row)
        }
    }

    func goPreviousDifference() {
        if let row = state.goPreviousHunk(caretRow: caretPresentationRow) {
            navigateToHunk(startRow: row)
        }
    }

    func goFirstDifference() {
        if let row = state.goFirstHunk() {
            navigateToHunk(startRow: row)
        }
    }

    func goLastDifference() {
        if let row = state.goLastHunk() {
            navigateToHunk(startRow: row)
        }
    }

    func goCurrentDifference() {
        if let row = state.goCurrentHunk(caretRow: caretPresentationRow) {
            navigateToHunk(startRow: row)
        }
    }

    func selectHunkAndScroll(_ index: Int) {
        guard state.selectHunk(index) != nil else { return }
        navigateToHunk(startRow: state.currentHunkStartRow)
    }

    func setPaneEditing(_ editing: Bool) {
        isEditingPane = editing
        if !editing {
            uncommittedEditSides = []
        }
    }

    func setUncommittedEditSides(_ sides: Set<DiffPaneSide>) {
        uncommittedEditSides = sides
        isEditingPane = !sides.isEmpty
    }

    func setPaneFocused(_ focused: Bool) {
        isPaneFocused = focused
    }

    func setCaretContext(row: Int?, side: DiffPaneSide?, viewportAnchorFraction: CGFloat? = nil) {
        let previousRow = lastKnownCaretRow
        let previousSide = lastKnownCaretSide
        lastKnownCaretRow = row
        lastKnownCaretSide = side
        if row != nil {
            lastKnownCaretViewportFraction = viewportAnchorFraction
        }
        guard row != previousRow || side != previousSide else { return }
        // Copy / Refresh pending restore owns the caret until DiffPanePair applies it.
        // Ignore intermediate stale reports (e.g. pre-copy side after a toolbar click).
        guard pendingCaretLineStartRestore == nil else { return }
        clearHunkSelectionIfCaretOutsideHunks(row)
    }

    private func clearHunkSelectionIfCaretOutsideHunks(_ row: Int?) {
        guard state.navigator.currentIndex != nil,
              let row,
              DiffLocationLayout.hunkIndex(containingRow: row, in: locationHunks) == nil
        else {
            return
        }
        state.clearHunkSelection()
    }

    func selectNearestHunkToCaret() {
        if let row = state.goNearestHunk(caretRow: caretPresentationRow) {
            navigateToHunk(startRow: row)
        }
    }

    func commitPaneEdit(side: DiffPaneSide, paneText: String) {
        let stripped = DiffPaneTextLayout.fileTextByDroppingGapRows(
            paneText: paneText,
            lines: state.presentation,
            side: side
        )
        let current = side == .left ? state.leftText : state.rightText
        let fileText = DiffPaneTextLayout.normalizingTrailingNewline(
            edited: stripped,
            previous: current
        )
        guard fileText != current else { return }

        lastSaveError = nil
        let before = state.makeEditSnapshot()
        state.applyEditedText(fileText, side: side)
        registerMergeUndo(restoring: before, actionName: "Edit")
    }

    func clearPendingCaretRemap() {
        pendingCaretRemap = nil
    }

    func clearPendingCaretLineStartRestore() {
        pendingCaretLineStartRestore = nil
    }

    private func performMergeCopy(
        actionName: String,
        targetSide: DiffPaneSide,
        _ operation: () -> MergeCaretRemap?
    ) -> Bool {
        lastSaveError = nil
        let before = state.makeEditSnapshot()
        guard let remap = operation() else { return false }
        registerMergeUndo(restoring: before, actionName: actionName)
        lastKnownCaretRow = remap.replacedStart
        lastKnownCaretSide = targetSide
        pendingCaretLineStartRestore = (side: targetSide, row: remap.replacedStart, focus: true)
        caretLineStartRestoreToken += 1
        pendingCaretRemap = remap
        paneApplyToken += 1
        return true
    }

    private func registerMergeUndo(restoring snapshot: FileCompareEditSnapshot, actionName: String) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreMerge(snapshot)
        }
        undoManager.setActionName(actionName)
        undoManager.endUndoGrouping()
        noteMergeUndoStackChanged()
    }

    private func restoreMerge(_ snapshot: FileCompareEditSnapshot) {
        let reciprocal = state.makeEditSnapshot()
        state.restoreEditSnapshot(snapshot)
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { target in
            target.restoreMerge(reciprocal)
        }
        undoManager.endUndoGrouping()
        paneApplyToken += 1
        uncommittedEditSides = []
        isEditingPane = false
        noteMergeUndoStackChanged()
        scrollToCurrentHunk()
    }

    private func clearMergeUndoHistory() {
        undoManager.removeAllActions(withTarget: self)
        noteMergeUndoStackChanged()
    }

    private func noteMergeUndoStackChanged() {
        mergeUndoRevision += 1
        NSApp.mainMenu?.update()
    }

    private func save(side: DiffPaneSide) {
        // Flush in-pane edits so Save works while the text view still has focus.
        commitPendingPaneEditsIfNeeded()

        lastSaveError = nil
        let text: String?
        let path: String?
        let format: TextFileFormat
        switch side {
        case .left:
            text = state.leftText
            path = state.leftPath
            format = state.leftFormat ?? .default
        case .right:
            text = state.rightText
            path = state.rightPath
            format = state.rightFormat ?? .default
        }
        guard let text else { return }

        let url: URL
        if let path {
            url = URL(fileURLWithPath: path)
        } else {
            guard let chosen = chooseSaveFile(title: side == .left ? "Save Left File" : "Save Right File") else {
                return
            }
            url = chosen
            switch side {
            case .left:
                state.leftPath = url.path
            case .right:
                state.rightPath = url.path
            }
        }

        do {
            try FileContentWriter.write(text, format: format, to: url)
            switch side {
            case .left:
                state.markLeftSaved()
            case .right:
                state.markRightSaved()
            }
        } catch {
            lastSaveError = "Failed to save \(side == .left ? "left" : "right") file"
        }
    }

    /// Resigns first responder so `textDidEndEditing` commits uncommitted pane keystrokes.
    private func commitPendingPaneEditsIfNeeded() {
        guard isEditingPane else { return }
        guard let window = NSApp.keyWindow else { return }
        if window.firstResponder is NSTextView {
            _ = window.makeFirstResponder(nil)
        }
    }

    private func scrollToCurrentHunk() {
        if let row = state.currentHunkStartRow {
            requestScroll(to: row)
        } else {
            scrollToRow = nil
            scrollViewportAnchorFraction = nil
        }
    }

    /// Scrolls to `startRow`, places the caret at that hunk start, and resigns pane focus.
    private func navigateToHunk(startRow: Int?) {
        guard let startRow else { return }
        requestScroll(to: startRow)
        let side = lastKnownCaretSide ?? .left
        lastKnownCaretRow = startRow
        lastKnownCaretSide = side
        pendingCaretLineStartRestore = (side: side, row: startRow, focus: false)
        caretLineStartRestoreToken += 1
    }

    private func requestScroll(to row: Int, viewportAnchorFraction: CGFloat? = nil) {
        scrollToken += 1
        scrollToRow = row
        scrollViewportAnchorFraction = viewportAnchorFraction
    }

    private func chooseFile(title: String) -> URL? {
        let panel = FilePanelFactory.makeOpenPanel(title: title, canChooseDirectories: false)
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseSaveFile(title: String) -> URL? {
        let panel = FilePanelFactory.makeSavePanel(title: title)
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func confirmDiscard(sideName: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Discard unsaved \(sideName) changes?"
        alert.informativeText = "The \(sideName) file has unsaved changes."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmDiscardRefresh() -> Bool {
        var dirtySides: [String] = []
        if state.isLeftDirty { dirtySides.append("left") }
        if state.isRightDirty { dirtySides.append("right") }

        let alert = NSAlert()
        alert.messageText = "Discard unsaved changes?"
        alert.informativeText =
            "Refreshing will discard unsaved changes to the \(dirtySides.joined(separator: " and ")) file\(dirtySides.count == 1 ? "" : "s")."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Reloads one side from disk without prompting about unsaved changes.
    private func reloadFromDisk(path: String, side: DiffPaneSide) {
        lastSaveError = nil
        let url = URL(fileURLWithPath: path)
        do {
            let loaded = try FileContentLoader.loadFile(from: url)
            switch side {
            case .left:
                state.setLeftText(loaded.text, path: path, format: loaded.format)
            case .right:
                state.setRightText(loaded.text, path: path, format: loaded.format)
            }
        } catch let error as FileLoadError {
            switch side {
            case .left:
                state.setLeftFailure(error, path: path)
            case .right:
                state.setRightFailure(error, path: path)
            }
            scrollToRow = nil
        } catch {
            switch side {
            case .left:
                state.setLeftFailure(.unreadable, path: path)
            case .right:
                state.setRightFailure(.unreadable, path: path)
            }
            scrollToRow = nil
        }
    }

    private func describe(_ error: FileLoadError) -> String {
        switch error {
        case .binary:
            return "binary file (cannot compare)"
        case .notUTF8:
            return "not valid UTF-8 or Shift_JIS text"
        case .unreadable:
            return "unreadable"
        }
    }
}
