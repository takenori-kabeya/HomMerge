import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class CompareTab: Identifiable {
    let id: UUID
    let session: CompareSessionViewModel

    init(id: UUID = UUID(), session: CompareSessionViewModel = CompareSessionViewModel()) {
        self.id = id
        self.session = session
    }

    var title: String {
        session.title
    }
}

@Observable
@MainActor
final class AppViewModel {
    var tabs: [CompareTab]
    var selectedTabID: CompareTab.ID
    /// Most recently selected tab IDs (newest at the end). Used when closing the selected tab.
    private var tabSelectionHistory: [CompareTab.ID] = []

    init() {
        let initial = CompareTab()
        self.tabs = [initial]
        self.selectedTabID = initial.id
    }

    init(restoring snapshot: WindowSnapshot) {
        let restoredTabs: [CompareTab]
        if snapshot.tabs.isEmpty {
            restoredTabs = [CompareTab()]
        } else {
            restoredTabs = snapshot.tabs.map { tabSnapshot in
                let tab = CompareTab()
                tab.session.restorePaths(
                    left: tabSnapshot.leftPath.map { URL(fileURLWithPath: $0) },
                    right: tabSnapshot.rightPath.map { URL(fileURLWithPath: $0) }
                )
                return tab
            }
        }
        self.tabs = restoredTabs
        let index = min(max(snapshot.selectedTabIndex, 0), restoredTabs.count - 1)
        self.selectedTabID = restoredTabs[index].id
        self.tabSelectionHistory = []
    }

    func makeSnapshot() -> WindowSnapshot {
        let selectedIndex = tabs.firstIndex(where: { $0.id == selectedTabID }) ?? 0
        return WindowSnapshot(
            selectedTabIndex: selectedIndex,
            tabs: tabs.map { tab in
                TabSnapshot(
                    leftPath: tab.session.leftURL?.path,
                    rightPath: tab.session.rightURL?.path
                )
            }
        )
    }

    var selectedTab: CompareTab? {
        tabs.first { $0.id == selectedTabID }
    }

    var selectedSession: CompareSessionViewModel? {
        selectedTab?.session
    }

    var selectedFileCompare: FileCompareViewModel? {
        selectedSession?.fileCompare
    }

    var selectedFolderCompare: FolderCompareViewModel? {
        selectedSession?.folderCompare
    }

    @discardableResult
    func addTab(select: Bool = true) -> CompareTab {
        let tab = CompareTab()
        tabs.append(tab)
        if select {
            setSelectedTab(tab.id)
        }
        return tab
    }

    func selectTab(_ id: CompareTab.ID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        setSelectedTab(id)
    }

    func closeTab(_ id: CompareTab.ID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        guard tab.session.confirmDiscardUnsavedChangesIfNeeded() else { return }

        let wasSelected = selectedTabID == id
        tabs.remove(at: index)
        tabSelectionHistory.removeAll { $0 == id }

        if tabs.isEmpty {
            let replacement = CompareTab()
            tabs = [replacement]
            tabSelectionHistory = []
            selectedTabID = replacement.id
            return
        }

        guard wasSelected else { return }

        if let mru = tabSelectionHistory.last(where: { candidate in
            tabs.contains(where: { $0.id == candidate })
        }) {
            selectedTabID = mru
            tabSelectionHistory.removeAll { $0 == mru }
        } else if index > 0 {
            selectedTabID = tabs[index - 1].id
        } else {
            selectedTabID = tabs[0].id
        }
    }

    var unsavedFileChangeTabCount: Int {
        tabs.filter(\.session.hasUnsavedFileChanges).count
    }

    /// Returns `false` when the user cancels discarding unsaved changes in this window.
    func confirmWindowClose() -> Bool {
        let dirtyCount = unsavedFileChangeTabCount
        guard dirtyCount > 0 else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Discard unsaved changes?"
        if dirtyCount == 1 {
            alert.informativeText = "This window has a tab with unsaved file compare changes."
        } else {
            alert.informativeText = "This window has \(dirtyCount) tabs with unsaved file compare changes."
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func openLeft() {
        ensureSelectedSession().openLeft()
    }

    func openRight() {
        ensureSelectedSession().openRight()
    }

    func compareSelected() {
        ensureSelectedSession().compare()
    }

    func openFileCompareInNewTab(left: URL, right: URL) {
        let tab = CompareTab()
        if let index = tabs.firstIndex(where: { $0.id == selectedTabID }) {
            tabs.insert(tab, at: index + 1)
        } else {
            tabs.append(tab)
        }
        setSelectedTab(tab.id)
        tab.session.openComparedFiles(left: left, right: right)
    }

    private func setSelectedTab(_ id: CompareTab.ID) {
        guard id != selectedTabID else { return }
        tabSelectionHistory.append(selectedTabID)
        selectedTabID = id
    }

    private func ensureSelectedSession() -> CompareSessionViewModel {
        if let session = selectedSession {
            return session
        }
        return addTab(select: true).session
    }
}
