import AppKit
import DiffEngine
import Foundation
import Observation

enum CompareSessionPhase {
    case idle
    case files(FileCompareViewModel)
    case folders(FolderCompareViewModel)
}

@Observable
@MainActor
final class CompareSessionViewModel {
    var leftURL: URL?
    var rightURL: URL?
    var phase: CompareSessionPhase = .idle
    var errorMessage: String?

    var title: String {
        let left = leftURL?.lastPathComponent
        let right = rightURL?.lastPathComponent
        switch (left, right) {
        case let (l?, r?):
            return "\(l) ↔ \(r)"
        case let (l?, nil):
            return l
        case let (nil, r?):
            return r
        case (nil, nil):
            return "Compare"
        }
    }

    var canCompare: Bool {
        leftURL != nil && rightURL != nil
    }

    var fileCompare: FileCompareViewModel? {
        if case .files(let viewModel) = phase {
            return viewModel
        }
        return nil
    }

    var folderCompare: FolderCompareViewModel? {
        if case .folders(let viewModel) = phase {
            return viewModel
        }
        return nil
    }

    var hasUnsavedFileChanges: Bool {
        fileCompare?.state.hasUnsavedChanges ?? false
    }

    var statusText: String {
        if let errorMessage {
            return errorMessage
        }
        switch phase {
        case .idle:
            if leftURL == nil && rightURL == nil {
                return "Open or drop items on both sides, then Compare"
            }
            if leftURL == nil || rightURL == nil {
                return "Open or drop items on both sides, then Compare"
            }
            return "Ready to compare — press Compare"
        case .files(let viewModel):
            return viewModel.statusText
        case .folders(let viewModel):
            return viewModel.statusText
        }
    }

    func setPath(_ url: URL, side: DiffPaneSide) {
        guard confirmDiscardUnsavedChangesIfNeeded() else { return }
        switch side {
        case .left:
            leftURL = url
        case .right:
            rightURL = url
        }
        clearResult()
    }

    /// Dock icon D&D when app is already running: left first, then right + auto compare.
    func applyDockDroppedFile(_ url: URL) {
        if leftURL == nil {
            setPath(url, side: .left)
        } else {
            setPath(url, side: .right)
            if canCompare {
                compare()
            }
        }
    }

    /// Clears one side's path and returns to the idle drop-target phase.
    /// The other side's path is kept.
    func clearPath(side: DiffPaneSide) {
        guard confirmDiscardUnsavedChangesIfNeeded() else { return }
        switch side {
        case .left:
            leftURL = nil
        case .right:
            rightURL = nil
        }
        clearResult()
    }

    func openLeft() {
        guard let url = choosePath(title: "Open Left") else { return }
        setPath(url, side: .left)
    }

    func openRight() {
        guard let url = choosePath(title: "Open Right") else { return }
        setPath(url, side: .right)
    }

    func compare() {
        errorMessage = nil

        switch ComparePairResolver.resolve(left: leftURL, right: rightURL) {
        case .incomplete:
            phase = .idle
            if leftURL == nil || rightURL == nil {
                errorMessage = "Specify both left and right paths"
            } else {
                errorMessage = "The specified path was not found"
            }
        case .mismatch:
            phase = .idle
            errorMessage = "Both sides must be files, or both sides must be folders"
        case .files:
            guard let leftURL, let rightURL else { return }
            let viewModel = FileCompareViewModel()
            viewModel.load(url: leftURL, side: .left)
            viewModel.load(url: rightURL, side: .right)
            phase = .files(viewModel)
        case .folders:
            guard let leftURL, let rightURL else { return }
            let viewModel = FolderCompareViewModel()
            viewModel.compare(left: leftURL, right: rightURL)
            phase = .folders(viewModel)
        }
    }

    /// Sets both paths and runs compare immediately (e.g. open from folder results).
    func openComparedFiles(left: URL, right: URL) {
        leftURL = left
        rightURL = right
        compare()
    }

    /// Restores path selection without running compare (launch session restore).
    func restorePaths(left: URL?, right: URL?) {
        leftURL = left
        rightURL = right
        phase = .idle
        errorMessage = nil
    }

    private func clearResult() {
        phase = .idle
        errorMessage = nil
    }

    /// Returns `false` when the user cancels discarding unsaved file-compare changes.
    @discardableResult
    func confirmDiscardUnsavedChangesIfNeeded() -> Bool {
        guard let fileCompare, fileCompare.state.hasUnsavedChanges else {
            return true
        }

        var dirtySides: [String] = []
        if fileCompare.state.isLeftDirty { dirtySides.append("left") }
        if fileCompare.state.isRightDirty { dirtySides.append("right") }

        let alert = NSAlert()
        alert.messageText = "Discard unsaved changes?"
        alert.informativeText =
            "The \(dirtySides.joined(separator: " and ")) file\(dirtySides.count == 1 ? " has" : "s have") unsaved changes."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func choosePath(title: String) -> URL? {
        let panel = FilePanelFactory.makeOpenPanel(title: title, canChooseDirectories: true)
        return panel.runModal() == .OK ? panel.url : nil
    }
}
