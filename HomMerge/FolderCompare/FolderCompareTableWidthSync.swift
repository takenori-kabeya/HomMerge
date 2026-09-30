import AppKit
import SwiftUI

/// Finds the SwiftUI `Table`'s `NSTableView` and restores / persists column widths.
struct FolderCompareTableWidthSync: NSViewRepresentable {
    func makeNSView(context: Context) -> FolderCompareTableWidthAnchorView {
        FolderCompareTableWidthAnchorView()
    }

    func updateNSView(_ nsView: FolderCompareTableWidthAnchorView, context: Context) {
        nsView.scheduleSync()
    }
}

final class FolderCompareTableWidthAnchorView: NSView {
    private var observedTable: NSTableView?
    private var isApplyingWidths = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleSync()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleSync()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func scheduleSync() {
        DispatchQueue.main.async { [weak self] in
            self?.syncWithTable()
        }
    }

    private func syncWithTable() {
        guard let table = enclosingTableView() else { return }
        if observedTable !== table {
            startObserving(table)
            applyStoredWidths(to: table)
        }
    }

    private func startObserving(_ table: NSTableView) {
        if let observedTable {
            NotificationCenter.default.removeObserver(
                self,
                name: NSTableView.columnDidResizeNotification,
                object: observedTable
            )
        }
        observedTable = table
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(columnDidResize(_:)),
            name: NSTableView.columnDidResizeNotification,
            object: table
        )
    }

    @objc private func columnDidResize(_ notification: Notification) {
        persistCurrentWidths()
    }

    private func applyStoredWidths(to table: NSTableView) {
        isApplyingWidths = true
        defer { isApplyingWidths = false }

        let stored = FolderCompareTablePreferences.load()
        for (index, column) in table.tableColumns.enumerated() {
            guard let id = Self.columnID(for: column, index: index) else { continue }
            column.minWidth = FolderCompareTablePreferences.minimumWidth(for: id)
            if let maximum = FolderCompareTablePreferences.maximumWidth(for: id) {
                column.maxWidth = maximum
            }
            column.width = stored[id] ?? FolderCompareTablePreferences.defaultWidth(for: id)
        }
    }

    private func persistCurrentWidths() {
        guard !isApplyingWidths, let table = observedTable else { return }

        var widths: [FolderCompareTableColumnID: CGFloat] = [:]
        for (index, column) in table.tableColumns.enumerated() {
            guard let id = Self.columnID(for: column, index: index) else { continue }
            widths[id] = column.width
        }
        FolderCompareTablePreferences.save(widths)
    }

    private func enclosingTableView() -> NSTableView? {
        var ancestor: NSView? = superview
        while let current = ancestor {
            if let table = current as? NSTableView {
                return table
            }
            if let table = Self.firstTableView(in: current) {
                return table
            }
            ancestor = current.superview
        }
        return nil
    }

    private static func firstTableView(in root: NSView) -> NSTableView? {
        if let table = root as? NSTableView {
            return table
        }
        for child in root.subviews {
            if let table = firstTableView(in: child) {
                return table
            }
        }
        return nil
    }

    static func columnID(for column: NSTableColumn, index: Int) -> FolderCompareTableColumnID? {
        if let id = FolderCompareTableColumnID(rawValue: column.identifier.rawValue) {
            return id
        }
        switch column.identifier.rawValue {
        case "Name":
            return .name
        case "Status":
            return .status
        case "Left Date":
            return .leftDate
        case "Right Date":
            return .rightDate
        case "Path":
            return .path
        default:
            guard FolderCompareTableColumnID.allCases.indices.contains(index) else {
                return nil
            }
            return FolderCompareTableColumnID.allCases[index]
        }
    }
}
