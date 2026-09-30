import AppKit
import DiffEngine
import SwiftUI

/// Side-by-side diff panes with synchronized vertical scrolling.
struct DiffPanePair: NSViewRepresentable {
    let lines: [SideBySideLine]
    let hunks: [DiffHunk]
    let currentHunkIndex: Int?
    let highlightedRowRange: Range<Int>?
    let scrollToRow: Int?
    let scrollToken: Int
    /// Optional viewport anchor for `scrollToRow` (`nil` uses the default top-quarter placement).
    let scrollViewportAnchorFraction: CGFloat?
    /// Bumped on Copy / Refresh so both panes force-rewrite even if local caches look stale.
    let paneApplyToken: Int
    /// Bumped to select the hunk nearest to the caret in the focused pane.
    let nearestHunkSelectToken: Int
    /// Set after Copy so panes remap the caret across the replaced hunk.
    let pendingCaretRemap: MergeCaretRemap?
    /// Bumped after Refresh with `pendingCaretLineStartRestore`.
    let caretLineStartRestoreToken: Int
    /// Set after Refresh / Copy / hunk nav to place the caret at a presentation row start.
    let pendingCaretLineStartRestore: (side: DiffPaneSide, row: Int, focus: Bool)?
    var mergeUndoManager: UndoManager?
    var onSelectHunk: (Int) -> Void
    var onCommitEdit: (DiffPaneSide, String) -> Void
    var onEditingChange: (Set<DiffPaneSide>) -> Void
    var onPaneFocusChange: (Bool) -> Void
    var onCaretContextChange: (Int?, DiffPaneSide?, CGFloat?) -> Void
    var onConsumeCaretRemap: () -> Void
    var onConsumeCaretLineStartRestore: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelectHunk: onSelectHunk,
            mergeUndoManager: mergeUndoManager,
            onCommitEdit: onCommitEdit,
            onEditingChange: onEditingChange,
            onPaneFocusChange: onPaneFocusChange,
            onCaretContextChange: onCaretContextChange,
            onConsumeCaretRemap: onConsumeCaretRemap,
            onConsumeCaretLineStartRestore: onConsumeCaretLineStartRestore
        )
    }

    func makeNSView(context: Context) -> DiffPaneHostView {
        let host = DiffPaneHostView()
        context.coordinator.host = host
        host.mergeUndoManager = mergeUndoManager
        host.onCommitEdit = { [weak coordinator = context.coordinator] side, text in
            coordinator?.onCommitEdit(side, text)
        }
        host.onEditingChange = { [weak coordinator = context.coordinator] sides in
            coordinator?.onEditingChange(sides)
        }
        host.onPaneFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.onPaneFocusChange(focused)
        }
        host.onCaretContextChange = { [weak coordinator = context.coordinator] row, side, fraction in
            coordinator?.onCaretContextChange(row, side, fraction)
        }
        host.syncCoordinator.attach(
            left: host.leftScrollView,
            right: host.rightScrollView,
            leftGutter: host.leftGutter.scrollView,
            rightGutter: host.rightGutter.scrollView
        )
        host.locationBar.onSelectHunk = { [weak coordinator = context.coordinator] index in
            coordinator?.onSelectHunk(index)
        }
        return host
    }

    func updateNSView(_ host: DiffPaneHostView, context: Context) {
        context.coordinator.onSelectHunk = onSelectHunk
        context.coordinator.mergeUndoManager = mergeUndoManager
        context.coordinator.onCommitEdit = onCommitEdit
        context.coordinator.onEditingChange = onEditingChange
        context.coordinator.onPaneFocusChange = onPaneFocusChange
        context.coordinator.onCaretContextChange = onCaretContextChange
        context.coordinator.onConsumeCaretRemap = onConsumeCaretRemap
        context.coordinator.onConsumeCaretLineStartRestore = onConsumeCaretLineStartRestore
        host.mergeUndoManager = mergeUndoManager
        host.onCommitEdit = { [weak coordinator = context.coordinator] side, text in
            coordinator?.onCommitEdit(side, text)
        }
        host.onEditingChange = { [weak coordinator = context.coordinator] sides in
            coordinator?.onEditingChange(sides)
        }
        host.onPaneFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.onPaneFocusChange(focused)
        }
        host.onCaretContextChange = { [weak coordinator = context.coordinator] row, side, fraction in
            coordinator?.onCaretContextChange(row, side, fraction)
        }
        host.locationBar.onSelectHunk = { [weak coordinator = context.coordinator] index in
            coordinator?.onSelectHunk(index)
        }

        if context.coordinator.lastPaneApplyToken != paneApplyToken {
            context.coordinator.lastPaneApplyToken = paneApplyToken
            host.forceApplyAllSides()
        }

        if context.coordinator.lastNearestHunkSelectToken != nearestHunkSelectToken {
            context.coordinator.lastNearestHunkSelectToken = nearestHunkSelectToken
            if let row = host.caretPresentationRow(in: lines),
               let index = DiffLocationLayout.hunkIndex(nearestToRow: row, in: hunks)
            {
                onSelectHunk(index)
            }
        }

        host.apply(
            lines: lines,
            hunks: hunks,
            currentHunkIndex: currentHunkIndex,
            highlightedRowRange: highlightedRowRange,
            caretRemap: pendingCaretRemap
        )
        if pendingCaretRemap != nil {
            onConsumeCaretRemap()
        }

        if context.coordinator.lastCaretLineStartRestoreToken != caretLineStartRestoreToken {
            context.coordinator.lastCaretLineStartRestoreToken = caretLineStartRestoreToken
            if let pendingCaretLineStartRestore {
                host.placeCaretAtStartOfRow(
                    pendingCaretLineStartRestore.row,
                    side: pendingCaretLineStartRestore.side,
                    lines: lines,
                    focus: pendingCaretLineStartRestore.focus
                )
                onConsumeCaretLineStartRestore()
            }
        }

        // Publish after apply / caret restore so stale pre-copy caret cannot clear a fresh hunk selection.
        host.publishPaneFocus()

        if let scrollToRow, context.coordinator.lastScrollToken != scrollToken {
            context.coordinator.lastScrollToken = scrollToken
            host.scrollToRow(
                scrollToRow,
                lines: lines,
                anchorFraction: scrollViewportAnchorFraction
            )
        }
    }

    /// Expand to the size SwiftUI proposes so Auto Layout / intrinsic size cannot collapse us to 1pt.
    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: DiffPaneHostView,
        context: Context
    ) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 800, height: 500))
    }

    final class Coordinator {
        var host: DiffPaneHostView?
        var lastScrollToken: Int = -1
        var lastPaneApplyToken: Int = -1
        var lastNearestHunkSelectToken: Int = -1
        var lastCaretLineStartRestoreToken: Int = -1
        var onSelectHunk: (Int) -> Void
        var mergeUndoManager: UndoManager?
        var onCommitEdit: (DiffPaneSide, String) -> Void
        var onEditingChange: (Set<DiffPaneSide>) -> Void
        var onPaneFocusChange: (Bool) -> Void
        var onCaretContextChange: (Int?, DiffPaneSide?, CGFloat?) -> Void
        var onConsumeCaretRemap: () -> Void
        var onConsumeCaretLineStartRestore: () -> Void

        init(
            onSelectHunk: @escaping (Int) -> Void,
            mergeUndoManager: UndoManager?,
            onCommitEdit: @escaping (DiffPaneSide, String) -> Void,
            onEditingChange: @escaping (Set<DiffPaneSide>) -> Void,
            onPaneFocusChange: @escaping (Bool) -> Void,
            onCaretContextChange: @escaping (Int?, DiffPaneSide?, CGFloat?) -> Void,
            onConsumeCaretRemap: @escaping () -> Void,
            onConsumeCaretLineStartRestore: @escaping () -> Void
        ) {
            self.onSelectHunk = onSelectHunk
            self.mergeUndoManager = mergeUndoManager
            self.onCommitEdit = onCommitEdit
            self.onEditingChange = onEditingChange
            self.onPaneFocusChange = onPaneFocusChange
            self.onCaretContextChange = onCaretContextChange
            self.onConsumeCaretRemap = onConsumeCaretRemap
            self.onConsumeCaretLineStartRestore = onConsumeCaretLineStartRestore
        }
    }
}

/// AppKit container that owns both panes and keeps their vertical scroll positions aligned.
final class DiffPaneHostView: NSView, NSTextViewDelegate {
    let leftScrollView: NSScrollView
    let rightScrollView: NSScrollView
    let leftGutter = DiffPaneGutterColumn()
    let rightGutter = DiffPaneGutterColumn()
    let locationBar = DiffLocationBarView()
    let syncCoordinator = SyncScrollCoordinator()
    var mergeUndoManager: UndoManager?
    var onCommitEdit: ((DiffPaneSide, String) -> Void)?
    var onEditingChange: ((Set<DiffPaneSide>) -> Void)?
    var onPaneFocusChange: ((Bool) -> Void)?
    var onCaretContextChange: ((Int?, DiffPaneSide?, CGFloat?) -> Void)?

    private let leftTextView: DiffPaneContentTextView
    private let rightTextView: DiffPaneContentTextView
    private var forceApplySides: Set<DiffPaneSide> = []
    private var pendingScrollSyncSide: DiffPaneSide?
    private var lastAppliedLines: [SideBySideLine] = []
    private var lastAppliedHighlightedRowRange: Range<Int>?
    private var lastAppliedHunks: [DiffHunk] = []
    private var lastAppliedCurrentHunkIndex: Int?
    private var lastAppliedTabWidth = EditorPreferences.resolvedTabWidth()
    /// Sides whose textView content has diverged from the last applied presentation (keystrokes).
    private var dirtySides: Set<DiffPaneSide> = []
    /// True while rewriting text storage from presentation (ignore programmatic textDidChange).
    private var isApplyingPresentation = false
    /// Last known caret presentation row (survives brief focus loss to the toolbar).
    private var lastCaretRow: Int?
    private var lastCaretSide: DiffPaneSide?

    private let locationBarWidth: CGFloat = 16

    /// Forces the next `apply` to rewrite both panes (Copy / Refresh).
    func forceApplyAllSides() {
        forceApplySides.insert(.left)
        forceApplySides.insert(.right)
    }

    /// Whether either content pane is the window first responder.
    func hasPaneFocus() -> Bool {
        window?.firstResponder === leftTextView || window?.firstResponder === rightTextView
    }

    /// True when a caret row is known (focused now, or remembered after focus left the pane).
    func hasCaretContext() -> Bool {
        hasPaneFocus() || lastCaretRow != nil
    }

    /// Notifies SwiftUI that pane focus / caret context may have changed.
    func publishPaneFocus() {
        refreshLastCaretFromFocusedPane()
        onPaneFocusChange?(hasCaretContext())
        let fraction = caretViewportAnchorFraction(forRow: lastCaretRow)
        onCaretContextChange?(lastCaretRow, lastCaretSide, fraction)
    }

    /// Presentation row under the caret in the focused pane, or the last remembered caret.
    func caretPresentationRow(in lines: [SideBySideLine]) -> Int? {
        refreshLastCaretFromFocusedPane(lines: lines)
        guard let lastCaretRow else { return nil }
        guard !lines.isEmpty else { return 0 }
        return min(max(lastCaretRow, 0), lines.count - 1)
    }

    /// Places a zero-length selection at the start of `row` on `side`.
    /// When `focus` is false, resigns first responder so the pane is not editing-focused.
    func placeCaretAtStartOfRow(_ row: Int, side: DiffPaneSide, lines: [SideBySideLine], focus: Bool = true) {
        guard !lines.isEmpty else { return }
        let clamped = DiffPaneTextLayout.clampedPresentationRow(row, lineCount: lines.count) ?? 0
        let textView = side == .left ? leftTextView : rightTextView
        let location = DiffPaneTextLayout.utf16Location(forRow: clamped, in: lines, side: side)
        let length = (textView.string as NSString).length
        let clampedLocation = min(max(location, 0), length)
        textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
        if focus {
            _ = window?.makeFirstResponder(textView)
        } else {
            _ = window?.makeFirstResponder(nil)
            onPaneFocusChange?(false)
        }
        lastCaretRow = clamped
        lastCaretSide = side
        let fraction = caretViewportAnchorFraction(forRow: clamped)
        onCaretContextChange?(lastCaretRow, lastCaretSide, fraction)
        publishPaneFocus()
    }

    /// Fraction of the left pane viewport height where `row` currently sits (0 = top, 1 = bottom).
    func caretViewportAnchorFraction(forRow row: Int?) -> CGFloat? {
        guard let row,
              !lastAppliedLines.isEmpty,
              let lineMinY = DiffPaneLayoutGeometry.lineMinY(
                forRow: row,
                in: lastAppliedLines,
                side: .left,
                textView: leftTextView,
                digitCount: nil,
                isGutter: false
              )
        else {
            return nil
        }
        let visibleHeight = leftScrollView.contentView.bounds.height
        let originY = leftScrollView.contentView.bounds.origin.y
        return DiffPaneTextLayout.viewportAnchorFraction(
            lineMinY: lineMinY,
            visibleOriginY: originY,
            visibleHeight: visibleHeight
        )
    }

    func syncGutterViewports() {
        leftScrollView.layoutSubtreeIfNeeded()
        rightScrollView.layoutSubtreeIfNeeded()
        leftGutter.matchViewport(to: leftScrollView)
        rightGutter.matchViewport(to: rightScrollView)
    }

    private func scheduleDeferredGutterSync() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.leftScrollView.layoutSubtreeIfNeeded()
            self.rightScrollView.layoutSubtreeIfNeeded()
            let y = self.leftScrollView.contentView.bounds.origin.y
            self.syncGutterViewports()
            self.syncCoordinator.setVerticalOffset(y)
            self.updateLocationBarViewport()
        }
    }

    private func refreshLastCaretFromFocusedPane(lines: [SideBySideLine]? = nil) {
        let textView: DiffPaneContentTextView
        let side: DiffPaneSide
        if window?.firstResponder === leftTextView {
            textView = leftTextView
            side = .left
        } else if window?.firstResponder === rightTextView {
            textView = rightTextView
            side = .right
        } else {
            return
        }
        guard let range = textView.selectedRanges.first as? NSRange else { return }
        if let lines, !lines.isEmpty {
            lastCaretRow = DiffPaneTextLayout.row(
                forUtf16Location: range.location,
                in: lines,
                side: side
            )
            lastCaretSide = side
            return
        }
        // Without presentation lines, approximate by counting newlines in the pane string.
        let prefix = (textView.string as NSString).substring(
            to: min(range.location, (textView.string as NSString).length)
        )
        lastCaretRow = prefix.reduce(0) { partial, character in
            character == "\n" ? partial + 1 : partial
        }
        lastCaretSide = side
    }

    override var undoManager: UndoManager? {
        mergeUndoManager ?? super.undoManager
    }

    override init(frame frameRect: NSRect) {
        leftTextView = DiffPaneContentTextView(frame: .zero)
        rightTextView = DiffPaneContentTextView(frame: .zero)
        leftScrollView = Self.makeContentScrollView(document: leftTextView)
        rightScrollView = Self.makeContentScrollView(document: rightTextView)
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        let height = bounds.height
        guard width > 0, height > 0 else { return }

        let paneWidth = max((width - locationBarWidth) / 2, 0)
        let leftGutterWidth = leftGutter.preferredWidth
        let rightGutterWidth = rightGutter.preferredWidth
        let leftContentWidth = max(paneWidth - leftGutterWidth, 0)
        let rightContentWidth = max(paneWidth - rightGutterWidth, 0)

        leftGutter.frame = NSRect(x: 0, y: 0, width: leftGutterWidth, height: height)
        leftScrollView.frame = NSRect(x: leftGutterWidth, y: 0, width: leftContentWidth, height: height)
        locationBar.frame = NSRect(x: paneWidth, y: 0, width: locationBarWidth, height: height)
        rightGutter.frame = NSRect(
            x: paneWidth + locationBarWidth,
            y: 0,
            width: rightGutterWidth,
            height: height
        )
        rightScrollView.frame = NSRect(
            x: paneWidth + locationBarWidth + rightGutterWidth,
            y: 0,
            width: rightContentWidth,
            height: height
        )
        syncGutterViewports()
        updateLocationBarViewport()
    }

    private func updateLocationBarViewport() {
        let originY = leftScrollView.contentView.bounds.origin.y
        let visibleHeight = leftScrollView.contentView.bounds.height
        let documentHeight = DiffPaneLayoutGeometry.layoutDocumentHeight(for: leftTextView)
        locationBar.visibleViewport = DiffLocationLayout.viewportFrame(
            visibleOriginY: Double(originY),
            visibleHeight: Double(visibleHeight),
            documentHeight: Double(documentHeight),
            barHeight: Double(locationBar.bounds.height)
        )
    }

    func apply(
        lines: [SideBySideLine],
        hunks: [DiffHunk],
        currentHunkIndex: Int?,
        highlightedRowRange: Range<Int>?,
        caretRemap: MergeCaretRemap? = nil
    ) {
        let presentationChanged = lines != lastAppliedLines
        let highlightChanged = highlightedRowRange != lastAppliedHighlightedRowRange
        let previousLines = lastAppliedLines

        let leftWrote = apply(
            lines: lines,
            previousLines: previousLines,
            side: .left,
            highlightedRowRange: highlightedRowRange,
            presentationChanged: presentationChanged,
            highlightChanged: highlightChanged,
            caretRemap: caretRemap,
            to: leftTextView,
            gutter: leftGutter
        )
        let rightWrote = apply(
            lines: lines,
            previousLines: previousLines,
            side: .right,
            highlightedRowRange: highlightedRowRange,
            presentationChanged: presentationChanged,
            highlightChanged: highlightChanged,
            caretRemap: caretRemap,
            to: rightTextView,
            gutter: rightGutter
        )

        // Only mark as applied when both panes actually wrote; otherwise a skipped side
        // would keep stale content while the cache claims the new presentation is live.
        if leftWrote && rightWrote {
            lastAppliedLines = lines
            lastAppliedHighlightedRowRange = highlightedRowRange
        }
        lastAppliedHunks = hunks
        lastAppliedCurrentHunkIndex = currentHunkIndex
        lastAppliedTabWidth = EditorPreferences.resolvedTabWidth()

        locationBar.hunks = hunks
        locationBar.totalRows = lines.count
        locationBar.currentHunkIndex = currentHunkIndex
        needsLayout = true

        if let pendingScrollSyncSide {
            let sourceScrollView = pendingScrollSyncSide == .left ? leftScrollView : rightScrollView
            syncCoordinator.setVerticalOffset(sourceScrollView.contentView.bounds.origin.y)
            self.pendingScrollSyncSide = nil
        }

        syncGutterViewports()
        syncCoordinator.setVerticalOffset(leftScrollView.contentView.bounds.origin.y)
        updateLocationBarViewport()
        scheduleDeferredGutterSync()
    }

    /// Scrolls so `row` is visible, using the left pane as the vertical source of truth.
    ///
    /// When `anchorFraction` is nil, places the row near the top quarter of the viewport
    /// (Next Diff / current hunk). When set (Refresh restore), keeps that relative position.
    func scrollToRow(_ row: Int, lines: [SideBySideLine], anchorFraction: CGFloat? = nil) {
        guard !lines.isEmpty else { return }

        let clampedRow = DiffPaneTextLayout.clampedPresentationRow(row, lineCount: lines.count) ?? 0
        let fraction = anchorFraction ?? 0.25

        syncGutterViewports()
        if let desiredY = DiffPaneLayoutGeometry.verticalOffsetAligningRow(
            clampedRow,
            in: lines,
            side: .left,
            textView: leftTextView,
            scrollView: leftScrollView,
            anchorFractionInViewport: fraction,
            digitCount: nil,
            isGutter: false
        ) {
            syncCoordinator.setVerticalOffset(desiredY)
        }
        updateLocationBarViewport()
        scheduleDeferredGutterSync()
    }

    private func setup() {
        wantsLayer = true
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .vertical)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        locationBar.translatesAutoresizingMaskIntoConstraints = true
        leftGutter.translatesAutoresizingMaskIntoConstraints = true
        rightGutter.translatesAutoresizingMaskIntoConstraints = true
        leftScrollView.translatesAutoresizingMaskIntoConstraints = true
        rightScrollView.translatesAutoresizingMaskIntoConstraints = true
        leftScrollView.autoresizingMask = []
        rightScrollView.autoresizingMask = []
        locationBar.autoresizingMask = []

        addSubview(leftGutter)
        addSubview(leftScrollView)
        addSubview(locationBar)
        addSubview(rightScrollView)
        addSubview(rightGutter)

        Self.configureContent(leftTextView)
        Self.configureContent(rightTextView)
        leftTextView.delegate = self
        rightTextView.delegate = self

        leftScrollView.clipsToBounds = true
        rightScrollView.clipsToBounds = true
        leftGutter.scrollView.clipsToBounds = true
        rightGutter.scrollView.clipsToBounds = true
        leftGutter.pairedContentScrollView = leftScrollView
        rightGutter.pairedContentScrollView = rightScrollView
        clipsToBounds = true

        leftScrollView.contentView.postsBoundsChangedNotifications = true
        rightScrollView.contentView.postsBoundsChangedNotifications = true
        leftScrollView.postsFrameChangedNotifications = true
        rightScrollView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentClipViewBoundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: leftScrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentClipViewBoundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: rightScrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentScrollViewFrameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: leftScrollView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentScrollViewFrameChanged(_:)),
            name: NSView.frameDidChangeNotification,
            object: rightScrollView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func userDefaultsDidChange(_ notification: Notification) {
        let width = EditorPreferences.resolvedTabWidth()
        guard width != lastAppliedTabWidth else { return }
        lastAppliedTabWidth = width
        forceApplyAllSides()
        apply(
            lines: lastAppliedLines,
            hunks: lastAppliedHunks,
            currentHunkIndex: lastAppliedCurrentHunkIndex,
            highlightedRowRange: lastAppliedHighlightedRowRange
        )
    }

    @objc private func contentClipViewBoundsChanged(_ notification: Notification) {
        syncGutterViewports()
        updateLocationBarViewport()
    }

    @objc private func contentScrollViewFrameChanged(_ notification: Notification) {
        syncGutterViewports()
        updateLocationBarViewport()
    }

    private func apply(
        lines: [SideBySideLine],
        previousLines: [SideBySideLine],
        side: DiffPaneSide,
        highlightedRowRange: Range<Int>?,
        presentationChanged: Bool,
        highlightChanged: Bool,
        caretRemap: MergeCaretRemap?,
        to textView: DiffPaneContentTextView,
        gutter: DiffPaneGutterColumn
    ) -> Bool {
        let digitCount = DiffPaneTextLayout.gutterDigitCount(lines: lines, side: side)
        gutter.preferredWidth = DiffPaneRenderer.gutterWidth(digitCount: digitCount)
        let tabWidth = EditorPreferences.resolvedTabWidth()

        let content = DiffPaneRenderer.makeContentAttributedString(
            lines: lines,
            side: side,
            highlightedRowRange: highlightedRowRange,
            tabWidth: tabWidth
        )
        let gutterText = DiffPaneRenderer.makeGutterAttributedString(
            lines: lines,
            side: side,
            digitCount: digitCount,
            highlightedRowRange: highlightedRowRange,
            tabWidth: tabWidth
        )

        let hasUncommittedEdits = dirtySides.contains(side)
        let shouldForceApply = forceApplySides.remove(side) != nil
        let shouldWrite = DiffPaneTextLayout.shouldApplyPaneContent(
            hasUncommittedEdits: hasUncommittedEdits,
            shouldForceApply: shouldForceApply,
            presentationChanged: presentationChanged,
            highlightChanged: highlightChanged
        )
        guard shouldWrite else { return false }

        isApplyingPresentation = true
        defer { isApplyingPresentation = false }

        let previousRange = textView.selectedRanges.first as? NSRange
        if textView.attributedString().isEqual(to: content) == false {
            textView.textStorage?.setAttributedString(content)
        }
        restoreSelection(
            on: textView,
            side: side,
            previousRange: previousRange,
            previousLines: previousLines,
            newLines: lines,
            caretRemap: caretRemap
        )
        gutter.apply(attributedString: gutterText)
        DiffPaneLayoutGeometry.refreshLayoutOnly(for: gutter.textView)
        refreshDocumentPresentation(for: textView)
        textView.presentationLines = lines
        textView.paneSide = side
        if dirtySides.remove(side) != nil {
            publishEditingState()
        }
        return true
    }

    private func shouldRemapCaret(for side: DiffPaneSide, textView: DiffPaneContentTextView) -> Bool {
        window?.firstResponder === textView || lastCaretSide == side
    }

    private func restoreSelection(
        on textView: DiffPaneContentTextView,
        side: DiffPaneSide,
        previousRange: NSRange?,
        previousLines: [SideBySideLine],
        newLines: [SideBySideLine],
        caretRemap: MergeCaretRemap?
    ) {
        let length = (textView.string as NSString).length
        guard length >= 0 else { return }

        if let caretRemap,
           shouldRemapCaret(for: side, textView: textView),
           let previousRange,
           !previousLines.isEmpty,
           !newLines.isEmpty
        {
            let previousLocation = previousRange.location
            let oldRow = DiffPaneTextLayout.row(
                forUtf16Location: previousLocation,
                in: previousLines,
                side: side
            )
            let oldRowStart = DiffPaneTextLayout.utf16Location(
                forRow: oldRow,
                in: previousLines,
                side: side
            )
            let oldColumn = max(previousLocation - oldRowStart, 0)
            let oldEnd = caretRemap.replacedStart + caretRemap.replacedOldCount
            let wasInside = oldRow >= caretRemap.replacedStart && oldRow < oldEnd
            let mappedRow = DiffPaneTextLayout.remappedPresentationRow(
                caretRow: oldRow,
                replacedStart: caretRemap.replacedStart,
                replacedOldCount: caretRemap.replacedOldCount,
                replacedNewCount: caretRemap.replacedNewCount
            )
            let newRow = min(max(mappedRow, 0), newLines.count - 1)
            let newRowStart = DiffPaneTextLayout.utf16Location(
                forRow: newRow,
                in: newLines,
                side: side
            )
            let newColumn: Int
            if wasInside {
                newColumn = 0
            } else {
                let rowText = DiffPaneTextLayout.text(for: newLines[newRow], side: side)
                newColumn = min(oldColumn, (rowText as NSString).length)
            }
            let location = min(newRowStart + newColumn, length)
            textView.setSelectedRange(NSRange(location: location, length: 0))
            lastCaretRow = newRow
            lastCaretSide = side
            return
        }

        if let previousRange {
            let location = min(max(previousRange.location, 0), length)
            let maxLength = length - location
            let selectionLength = min(max(previousRange.length, 0), maxLength)
            textView.setSelectedRange(NSRange(location: location, length: selectionLength))
        }
    }

    func textDidChange(_ notification: Notification) {
        guard !isApplyingPresentation else { return }
        guard let textView = notification.object as? DiffPaneContentTextView else { return }
        let side: DiffPaneSide = textView === leftTextView ? .left : .right
        dirtySides.insert(side)
        publishEditingState()
    }

    func textDidBeginEditing(_ notification: Notification) {
        publishPaneFocus()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isApplyingPresentation else { return }
        guard notification.object is DiffPaneContentTextView else { return }
        publishPaneFocus()
    }

    func textDidEndEditing(_ notification: Notification) {
        guard let textView = notification.object as? DiffPaneContentTextView else { return }
        let side: DiffPaneSide = textView === leftTextView ? .left : .right
        // Only commit real keystrokes. Committing after Copy/Refresh with a stale pane string
        // against a newer presentation corrupts merge results.
        if dirtySides.contains(side) {
            commitEdit(from: textView)
        }
        DispatchQueue.main.async { [weak self] in
            self?.publishEditingState()
            self?.publishPaneFocus()
        }
    }

    private func commitEdit(from textView: DiffPaneContentTextView) {
        let side: DiffPaneSide = textView === leftTextView ? .left : .right
        dirtySides.remove(side)
        forceApplySides.insert(.left)
        forceApplySides.insert(.right)
        pendingScrollSyncSide = side
        onCommitEdit?(side, textView.string)
    }

    /// `isEditingPane` / Copy disable means uncommitted keystrokes, not caret/focus alone.
    private func publishEditingState() {
        onEditingChange?(dirtySides)
    }

    /// Forces layout and clip refresh after attributed-string replacement so Copy Left/Right
    /// does not leave a stale blank viewport until the next user scroll.
    private func refreshDocumentPresentation(for textView: DiffPaneContentTextView) {
        DiffPaneLayoutGeometry.refreshDocumentPresentation(for: textView)
    }

    private static func makeContentScrollView(document textView: NSTextView) -> NSScrollView {
        let scrollView = NSScrollView(frame: .zero)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.documentView = textView
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return scrollView
    }

    private static func configureContent(_ textView: DiffPaneContentTextView) {
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = false
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(
            width: DiffPaneRenderer.contentHorizontalPadding,
            height: DiffPaneRenderer.contentVerticalPadding
        )
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.exclusionPaths = []
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
    }
}

/// Content text view for a diff pane (line numbers live in a separate gutter column).
final class DiffPaneContentTextView: NSTextView {
    var presentationLines: [SideBySideLine] = []
    var paneSide: DiffPaneSide = .left
    /// Defaults used for Tab insertion; tests may inject a suite-backed instance.
    var editorDefaults: UserDefaults = .standard

    private var hostView: DiffPaneHostView? {
        enclosingScrollView?.superview as? DiffPaneHostView
    }

    override var undoManager: UndoManager? {
        hostView?.undoManager ?? super.undoManager
    }

    override func insertTab(_ sender: Any?) {
        let selection = selectedRange()
        let nsString = string as NSString
        if selectionSpansMultipleLines(selection, in: nsString) {
            indentLines(in: selection, nsString: nsString)
            return
        }

        let lineRange = nsString.lineRange(for: NSRange(location: selection.location, length: 0))
        let prefixLength = max(selection.location - lineRange.location, 0)
        let prefix = nsString.substring(
            with: NSRange(location: lineRange.location, length: prefixLength)
        )
        let text = EditorPreferences.insertionString(
            linePrefixBeforeCaret: prefix,
            defaults: editorDefaults
        )
        if text == "\t" {
            super.insertTab(sender)
        } else {
            insertText(text, replacementRange: selection)
        }
    }

    override func insertBacktab(_ sender: Any?) {
        let selection = selectedRange()
        let nsString = string as NSString
        let tabWidth = EditorPreferences.resolvedTabWidth(defaults: editorDefaults)
        let coverage = lineCoverage(for: selection, in: nsString)

        var rebuilt = ""
        var removedBeforeCaret = 0
        var index = coverage.location
        while index < coverage.location + coverage.length {
            let lineRange = nsString.lineRange(for: NSRange(location: index, length: 0))
            let line = nsString.substring(with: lineRange)
            let contentLength = line.hasSuffix("\n")
                ? (line as NSString).length - 1
                : (line as NSString).length
            let content = (line as NSString).substring(
                with: NSRange(location: 0, length: contentLength)
            )
            let remove = EditorPreferences.leadingUnindentLength(line: content, tabWidth: tabWidth)
            let suffixStart = lineRange.location + remove
            let suffixLength = lineRange.location + lineRange.length - suffixStart
            rebuilt += nsString.substring(with: NSRange(location: suffixStart, length: suffixLength))

            if selection.length == 0, selection.location > lineRange.location {
                removedBeforeCaret += min(remove, selection.location - lineRange.location)
            }

            index = lineRange.location + lineRange.length
        }

        guard rebuilt != nsString.substring(with: coverage) else {
            return
        }

        if shouldChangeText(in: coverage, replacementString: rebuilt) {
            replaceCharacters(in: coverage, with: rebuilt)
            didChangeText()
            if selection.length > 0 {
                setSelectedRange(
                    NSRange(location: coverage.location, length: (rebuilt as NSString).length)
                )
            } else {
                let newLocation = max(selection.location - removedBeforeCaret, coverage.location)
                setSelectedRange(NSRange(location: newLocation, length: 0))
            }
        }
    }

    private func indentLines(in selection: NSRange, nsString: NSString) {
        let coverage = lineCoverage(for: selection, in: nsString)
        let prefix = EditorPreferences.lineIndentPrefix(defaults: editorDefaults)

        var rebuilt = ""
        var lineCount = 0
        var index = coverage.location
        while index < coverage.location + coverage.length {
            let lineRange = nsString.lineRange(for: NSRange(location: index, length: 0))
            rebuilt += prefix
            rebuilt += nsString.substring(with: lineRange)
            lineCount += 1
            index = lineRange.location + lineRange.length
        }

        guard lineCount > 0 else { return }

        if shouldChangeText(in: coverage, replacementString: rebuilt) {
            replaceCharacters(in: coverage, with: rebuilt)
            didChangeText()
            setSelectedRange(
                NSRange(location: coverage.location, length: (rebuilt as NSString).length)
            )
        }
    }

    private func lineCoverage(for selection: NSRange, in nsString: NSString) -> NSRange {
        if selection.length == 0 {
            return nsString.lineRange(for: NSRange(location: selection.location, length: 0))
        }
        let end = max(selection.location + selection.length - 1, selection.location)
        let startLine = nsString.lineRange(for: NSRange(location: selection.location, length: 0))
        let endLine = nsString.lineRange(for: NSRange(location: end, length: 0))
        return NSRange(
            location: startLine.location,
            length: endLine.location + endLine.length - startLine.location
        )
    }

    private func selectionSpansMultipleLines(_ selection: NSRange, in nsString: NSString) -> Bool {
        guard selection.length > 0 else { return false }
        let coverage = lineCoverage(for: selection, in: nsString)
        let firstLine = nsString.lineRange(for: NSRange(location: coverage.location, length: 0))
        return coverage.location + coverage.length > firstLine.location + firstLine.length
    }

    @objc func undo(_ sender: Any?) {
        undoManager?.undo()
    }

    @objc func redo(_ sender: Any?) {
        undoManager?.redo()
    }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(undo(_:)):
            return undoManager?.canUndo ?? false
        case #selector(redo(_:)):
            return undoManager?.canRedo ?? false
        default:
            return super.validateUserInterfaceItem(item)
        }
    }

    override func copy(_ sender: Any?) {
        guard let range = selectedRanges.first as? NSRange,
              range.length > 0,
              !presentationLines.isEmpty
        else {
            super.copy(sender)
            return
        }
        let text = DiffPaneTextLayout.clipboardTextByDroppingGapRows(
            paneText: string,
            selectedRange: range,
            lines: presentationLines,
            side: paneSide
        )
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            // Defer so window.firstResponder is this view when publish runs.
            DispatchQueue.main.async { [weak self] in
                self?.hostView?.publishPaneFocus()
            }
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            DispatchQueue.main.async { [weak self] in
                self?.hostView?.publishPaneFocus()
            }
        }
        return resigned
    }
}

/// Forwards scroll wheel events to the paired content pane scroll view.
final class DiffPaneGutterScrollView: NSScrollView {
    weak var pairedContentScrollView: NSScrollView?

    override func scrollWheel(with event: NSEvent) {
        if let pairedContentScrollView {
            pairedContentScrollView.scrollWheel(with: event)
        }
    }
}

/// Gutter line-number text view that forwards scroll wheel events to the content pane.
final class DiffPaneGutterTextView: NSTextView {
    weak var pairedContentScrollView: NSScrollView?

    override func scrollWheel(with event: NSEvent) {
        if let pairedContentScrollView {
            pairedContentScrollView.scrollWheel(with: event)
        }
    }
}

/// Line-number column backed by its own scroll view, synced vertically with the content pane.
final class DiffPaneGutterColumn: NSView {
    let scrollView: DiffPaneGutterScrollView
    let textView: DiffPaneGutterTextView
    weak var pairedContentScrollView: NSScrollView? {
        didSet {
            scrollView.pairedContentScrollView = pairedContentScrollView
            textView.pairedContentScrollView = pairedContentScrollView
        }
    }

    var preferredWidth: CGFloat = DiffPaneRenderer.gutterWidth(
        digitCount: DiffPaneTextLayout.minimumGutterDigitCount
    ) {
        didSet {
            guard preferredWidth != oldValue else { return }
            needsLayout = true
            superview?.needsLayout = true
        }
    }

    private let separator = NSView()

    override init(frame frameRect: NSRect) {
        textView = Self.makeTextView()
        scrollView = Self.makeScrollView(document: textView)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        addSubview(scrollView)
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(separator)
        scrollView.pairedContentScrollView = pairedContentScrollView
        textView.pairedContentScrollView = pairedContentScrollView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func scrollWheel(with event: NSEvent) {
        if let pairedContentScrollView {
            pairedContentScrollView.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        separator.frame = NSRect(x: bounds.width - 1, y: 0, width: 1, height: bounds.height)
    }

    func apply(attributedString: NSAttributedString) {
        guard textView.attributedString().isEqual(to: attributedString) == false else { return }
        textView.textStorage?.setAttributedString(attributedString)
    }

    /// Matches the gutter clip's visible height to the paired content scroll view.
    func matchViewport(to contentScrollView: NSScrollView) {
        contentScrollView.layoutSubtreeIfNeeded()
        let contentClipHeight = contentScrollView.contentView.bounds.height
        let gutterClipView = scrollView.contentView
        let gutterClipHeight = gutterClipView.bounds.height
        let bottomInset = DiffPaneLayoutGeometry.gutterBottomInset(
            contentClipHeight: contentClipHeight,
            gutterClipHeight: gutterClipHeight
        )
        let currentInsets = gutterClipView.contentInsets
        guard currentInsets.bottom != bottomInset else { return }

        gutterClipView.contentInsets = NSEdgeInsets(
            top: currentInsets.top,
            left: currentInsets.left,
            bottom: bottomInset,
            right: currentInsets.right
        )
        scrollView.reflectScrolledClipView(gutterClipView)
    }

    private static func makeScrollView(document textView: NSTextView) -> DiffPaneGutterScrollView {
        let scrollView = DiffPaneGutterScrollView(frame: .zero)
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.documentView = textView
        scrollView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return scrollView
    }

    private static func makeTextView() -> DiffPaneGutterTextView {
        let view = DiffPaneGutterTextView(frame: .zero)
        view.isEditable = false
        view.isSelectable = false
        view.isRichText = true
        view.drawsBackground = true
        view.backgroundColor = NSColor.textBackgroundColor
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textContainerInset = NSSize(
            width: DiffPaneRenderer.gutterHorizontalPadding,
            height: DiffPaneRenderer.contentVerticalPadding
        )
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        return view
    }
}
