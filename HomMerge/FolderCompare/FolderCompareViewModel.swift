import AppKit
import DiffEngine
import Foundation
import Observation

enum OverwriteChoice {
    case replace
    case skip
    case abort
}

@Observable
@MainActor
final class FolderCompareViewModel {
    private(set) var state = FolderCompareState()
    private(set) var leftPath: String?
    private(set) var rightPath: String?
    private(set) var statusText = "Open two folders to compare"
    var selectedEntryIDs: Set<FolderEntry.ID> = []

    var leftTitle: String {
        leftPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Left Folder"
    }

    var rightTitle: String {
        rightPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Right Folder"
    }

    var excludeHidden: Bool {
        get { state.options.excludeHidden }
        set {
            var options = state.options
            options.excludeHidden = newValue
            state.options = options
            refreshStatus()
        }
    }

    var showOnlyDifferences: Bool {
        get { state.showOnlyDifferences }
        set {
            state.showOnlyDifferences = newValue
            refreshStatus()
        }
    }

    var displayedEntries: [FolderEntry] {
        state.displayedEntries
    }

    var selectedEntries: [FolderEntry] {
        selectedEntryIDs
            .compactMap { findEntry(id: $0, in: state.entries) }
            .sorted { $0.relativePath < $1.relativePath }
    }

    var canOpenSelectedFileCompare: Bool {
        FolderCompareSelection.canCompare(entries: selectedEntries)
    }

    var canCopyToRight: Bool {
        FolderCompareSelection.canCopy(
            entries: selectedEntries,
            sourceSide: .left,
            destinationRootPath: rightPath
        )
    }

    var canCopyToLeft: Bool {
        FolderCompareSelection.canCopy(
            entries: selectedEntries,
            sourceSide: .right,
            destinationRootPath: leftPath
        )
    }

    var canDeleteSelected: Bool {
        FolderCompareSelection.canDelete(entries: selectedEntries)
    }

    /// Runs a folder compare for the given roots. Call only after an explicit Compare action.
    func compare(left: URL, right: URL) {
        leftPath = left.path
        rightPath = right.path
        runCompare(preservingSelectionIDs: nil)
    }

    /// Re-scans the current folder roots from disk.
    func refresh() {
        runCompare(preservingSelectionIDs: nil)
    }

    func select(_ entry: FolderEntry?) {
        if let entry {
            selectedEntryIDs = [entry.id]
        } else {
            selectedEntryIDs = []
        }
    }

    func entry(withID id: FolderEntry.ID) -> FolderEntry? {
        findEntry(id: id, in: state.entries)
    }

    func fileURLsForCompare(entry: FolderEntry) -> (URL, URL)? {
        guard entry.canOpenFileCompare,
              let left = entry.leftURL,
              let right = entry.rightURL
        else {
            return nil
        }
        return (left, right)
    }

    func compareTargetsForSelection() -> [(URL, URL)] {
        FolderCompareSelection.compareTargets(entries: selectedEntries).compactMap { entry in
            fileURLsForCompare(entry: entry)
        }
    }

    func openSelectedFileCompares(onOpen: (URL, URL) -> Void) {
        for pair in compareTargetsForSelection() {
            onOpen(pair.0, pair.1)
        }
    }

    func openCrossFileCompare(left: URL, right: URL, onOpen: (URL, URL) -> Void) {
        onOpen(left, right)
    }

    func copySelectedToRight() {
        copySelected(to: .right)
    }

    func copySelectedToLeft() {
        copySelected(to: .left)
    }

    func deleteSelected() {
        let targets = FolderCompareSelection.deleteTargets(entries: selectedEntries)
        guard !targets.isEmpty else { return }

        let preservedIDs = selectedEntryIDs
        let relativePaths = targets.map(\.relativePath)
        guard confirmMoveToTrash(relativePaths: relativePaths) else { return }

        for target in targets {
            guard let url = FolderCompareSelection.trashURL(for: target) else { continue }
            do {
                try FolderFileTrash.moveToTrash(at: url)
            } catch {
                presentDeleteError(error)
                return
            }
        }

        runCompare(preservingSelectionIDs: preservedIDs)
    }

    private func copySelected(to destinationSide: DiffPaneSide) {
        let entries = selectedEntries
        guard !entries.isEmpty else { return }
        guard destinationRootPath(for: destinationSide) != nil else { return }

        let preservedIDs = selectedEntryIDs
        let selectionKind = FolderCompareSelection.kind(for: entries)
        var shouldContinue = true

        switch selectionKind {
        case .empty:
            return
        case .files(let files):
            for file in files {
                guard shouldContinue else { break }
                shouldContinue = copySingleFileSequential(entry: file, destinationSide: destinationSide)
            }
        case .directories(let directories):
            do {
                shouldContinue = try copyDirectoriesBatch(
                    directories,
                    destinationSide: destinationSide
                )
            } catch {
                presentCopyError(error, messageText: "Could not copy folder")
                return
            }
        case .mixed(let directories, let files):
            do {
                shouldContinue = try copyDirectoriesBatch(
                    directories,
                    destinationSide: destinationSide
                )
            } catch {
                presentCopyError(error, messageText: "Could not copy folder")
                return
            }
            if shouldContinue {
                for file in files {
                    guard shouldContinue else { break }
                    shouldContinue = copySingleFileSequential(entry: file, destinationSide: destinationSide)
                }
            }
        }

        runCompare(preservingSelectionIDs: preservedIDs)
    }

    @discardableResult
    private func copySingleFileSequential(entry: FolderEntry, destinationSide: DiffPaneSide) -> Bool {
        let sourceURL: URL?
        switch destinationSide {
        case .right:
            sourceURL = entry.leftURL
        case .left:
            sourceURL = entry.rightURL
        }
        guard let sourceURL else { return true }

        guard let destinationRootPath = destinationRootPath(for: destinationSide) else { return false }
        let destinationRoot = URL(fileURLWithPath: destinationRootPath, isDirectory: true)
        let destinationURL = entryURL(for: entry, side: destinationSide)
            ?? FolderFileCopy.destinationURL(root: destinationRoot, relativePath: entry.relativePath)

        let destinationExists = FileManager.default.fileExists(atPath: destinationURL.path)
        if destinationExists {
            switch confirmOverwriteChoice(fileName: destinationURL.lastPathComponent) {
            case .replace:
                break
            case .skip:
                return true
            case .abort:
                return false
            }
        }

        do {
            try FolderFileCopy.copyFile(
                from: sourceURL,
                to: destinationURL,
                overwrite: destinationExists
            )
            return true
        } catch {
            presentCopyError(error, messageText: "Could not copy file")
            return false
        }
    }

    @discardableResult
    private func copyDirectoriesBatch(
        _ directories: [FolderEntry],
        destinationSide: DiffPaneSide
    ) throws -> Bool {
        guard let destinationRootPath = destinationRootPath(for: destinationSide) else { return false }
        let destinationRoot = URL(fileURLWithPath: destinationRootPath, isDirectory: true)
        let sourceSide: DiffPaneSide = destinationSide == .right ? .left : .right

        let plans = try directories.map { directory in
            try FolderFileCopy.copyPlan(
                for: directory,
                destinationRoot: destinationRoot,
                sourceSide: sourceSide,
                options: state.options
            )
        }
        let mergedPlan = FolderFileCopy.mergeCopyPlans(plans)

        let confirmationRequired = mergedPlan.filter(\.requiresOverwriteConfirmation)
        if !confirmationRequired.isEmpty {
            let paths = confirmationRequired.map(\.relativePath).sorted()
            guard confirmOverwrite(files: paths) else { return false }
        }

        try FolderFileCopy.executeCopyPlan(mergedPlan)
        return true
    }

    private func destinationRootPath(for destinationSide: DiffPaneSide) -> String? {
        switch destinationSide {
        case .right: return rightPath
        case .left: return leftPath
        }
    }

    private func entryURL(for entry: FolderEntry, side: DiffPaneSide) -> URL? {
        switch side {
        case .left: return entry.leftURL
        case .right: return entry.rightURL
        }
    }

    private func confirmOverwriteChoice(fileName: String) -> OverwriteChoice {
        let alert = NSAlert()
        alert.messageText = "Replace existing file?"
        alert.informativeText = "\"\(fileName)\" already exists. Replace this file?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Yes")
        alert.addButton(withTitle: "No")
        alert.addButton(withTitle: "Stop")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .replace
        case .alertSecondButtonReturn:
            return .skip
        default:
            return .abort
        }
    }

    private func confirmOverwrite(files: [String]) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Replace files with differences?"
        alert.informativeText = "\(files.count) file\(files.count == 1 ? "" : "s") will be overwritten."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.autohidesScrollers = true

        let textView = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
        textView.isEditable = false
        textView.isSelectable = true
        textView.string = files.joined(separator: "\n")
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = NSView.AutoresizingMask.width
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        alert.accessoryView = scrollView

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmMoveToTrash(relativePaths: [String]) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        if relativePaths.count == 1 {
            let fileName = URL(fileURLWithPath: relativePaths[0]).lastPathComponent
            alert.messageText = "Move to Trash?"
            alert.informativeText = "\"\(fileName)\" will be moved to the Trash."
        } else {
            alert.messageText = "Move files to the Trash?"
            alert.informativeText =
                "\(relativePaths.count) file\(relativePaths.count == 1 ? "" : "s") will be moved to the Trash."

            let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
            scrollView.hasVerticalScroller = true
            scrollView.borderType = .bezelBorder
            scrollView.autohidesScrollers = true

            let textView = NSTextView(frame: NSRect(origin: .zero, size: scrollView.contentSize))
            textView.isEditable = false
            textView.isSelectable = true
            textView.string = relativePaths.joined(separator: "\n")
            textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            textView.isVerticallyResizable = true
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = NSView.AutoresizingMask.width
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )

            scrollView.documentView = textView
            alert.accessoryView = scrollView
        }

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentDeleteError(_ error: Error) {
        presentCopyError(error, messageText: "Could not move file to the Trash")
    }

    private func presentCopyError(_ error: Error, messageText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func runCompare(preservingSelectionIDs: Set<FolderEntry.ID>?) {
        selectedEntryIDs = []
        guard let leftPath, let rightPath else {
            statusText = "Open two folders to compare"
            state.clear()
            return
        }

        do {
            try state.compare(
                left: URL(fileURLWithPath: leftPath),
                right: URL(fileURLWithPath: rightPath)
            )
            if let preservingSelectionIDs {
                var restored: Set<FolderEntry.ID> = []
                for id in preservingSelectionIDs {
                    if findEntry(id: id, in: state.entries) != nil {
                        restored.insert(id)
                    }
                }
                selectedEntryIDs = restored
            }
            refreshStatus()
        } catch {
            state.clear()
            statusText = "Failed to compare folders"
        }
    }

    private func refreshStatus() {
        guard state.hasResult else {
            statusText = "Open two folders to compare"
            return
        }
        let flat = state.result?.flatEntries ?? []
        let files = flat.filter { $0.kind == .file }
        let different = files.filter { $0.status != .identical }.count
        let identical = files.count - different
        statusText =
            "\(files.count) files — \(different) different, \(identical) identical"
            + (showOnlyDifferences ? " (filtered)" : "")
    }

    private func findEntry(id: FolderEntry.ID, in entries: [FolderEntry]) -> FolderEntry? {
        for entry in entries {
            if entry.id == id {
                return entry
            }
            if let nested = findEntry(id: id, in: entry.children) {
                return nested
            }
        }
        return nil
    }
}
